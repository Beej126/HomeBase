# MissionControl - PowerShell WPF Application with WebView2 Controls
# Main Entry Point

# Ensure running with PowerShell 7.5 or higher
#Requires -Version 7.5

param(
    [string]$ScriptDirectory = (Split-Path -Parent $PSCommandPath)
)

try {

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Load WebView2 assemblies more robustly
$webView2Dlls = @()

# Search for WebView2 in NuGet cache
$nugetPath = "$env:USERPROFILE\.nuget\packages\microsoft.web.webview2"
if (Test-Path $nugetPath) {
    $latestVersion = Get-ChildItem -Path $nugetPath -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if ($latestVersion) {
        $wpfDll = Join-Path $latestVersion.FullName "lib\netcoreapp3.1\Microsoft.Web.WebView2.Wpf.dll"
        $coreDll = Join-Path $latestVersion.FullName "lib\netcoreapp3.1\Microsoft.Web.WebView2.Core.dll"
        
        if (Test-Path $wpfDll) { $webView2Dlls += $wpfDll }
        if (Test-Path $coreDll) { $webView2Dlls += $coreDll }
    }
}

# Try Visual Studio installations
$vsInstalls = @(
    "C:\Program Files\Microsoft Visual Studio\2022\Community",
    "C:\Program Files\Microsoft Visual Studio\2022\Professional", 
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise"
)

foreach ($vsPath in $vsInstalls) {
    if (Test-Path $vsPath) {
        $wpfDll = Get-ChildItem -Path $vsPath -Filter "Microsoft.Web.WebView2.Wpf.dll" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        $coreDll = Get-ChildItem -Path $vsPath -Filter "Microsoft.Web.WebView2.Core.dll" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        
        if ($wpfDll -and $webView2Dlls -notcontains $wpfDll.FullName) { 
            $webView2Dlls += $wpfDll.FullName 
        }
        if ($coreDll -and $webView2Dlls -notcontains $coreDll.FullName) { 
            $webView2Dlls += $coreDll.FullName 
        }
    }
}

# Load the assemblies - don't break after first, load all
$script:webView2Available = $false
foreach ($dll in $webView2Dlls | Select-Object -Unique) {
    try {
        [System.Reflection.Assembly]::LoadFrom($dll) | Out-Null
        Write-Host "✓ Loaded WebView2 from: $dll" -ForegroundColor Green
        $script:webView2Available = $true
    }
    catch {
        Write-Host "⚠ Could not load: $dll - $_" -ForegroundColor Yellow
    }
}

if (-not $script:webView2Available) {
    Write-Host "⚠ WebView2 not found. Install from: https://developer.microsoft.com/en-us/microsoft-edge/webview2/" -ForegroundColor Yellow
}

# Import YAML parsing
$yamlPath = Join-Path $ScriptDirectory "config.yml"
if (-not (Test-Path $yamlPath)) {
    Write-Error "config.yml not found at $yamlPath"
    exit 1
}

# Recursive YAML parser for nested panel definitions
function Parse-YamlPanels {
    param(
        [string]$Content,
        [int]$IndentLevel = 4
    )
    
    $items = @()
    $indent = ' ' * $IndentLevel
    $lines = $Content -split "`n"
    $i = 0
    
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        
        # Check if this is a horizontal group at current indent
        if ($line -match "^$indent- hgroup:\s*$") {
            # Find the extent of this group
            $groupStart = $i + 1
            $groupEnd = $groupStart
            
            # Scan ahead to find all content belonging to this group
            while ($groupEnd -lt $lines.Count) {
                $nextLine = $lines[$groupEnd]
                # Stop if we hit another item at the same indent level
                if ($nextLine -match "^$indent- " -and $groupEnd -gt $groupStart) {
                    break
                }
                $groupEnd++
            }
            
            # Extract the nested content
            $nestedContent = ($lines[$groupStart..($groupEnd-1)] -join "`n")
            
            # Detect the actual indentation of children by finding first non-empty line
            $childIndent = $IndentLevel + 2
            foreach ($childLine in ($lines[$groupStart..($groupEnd-1)])) {
                if ($childLine -match '^\s+\S') {
                    # Found first non-empty line, measure its indentation
                    $childLine -match '^(\s+)' | Out-Null
                    $childIndent = $matches[1].Length
                    break
                }
            }
            
            # Recursively parse the nested panels with detected indentation
            $nestedPanels = Parse-YamlPanels -Content $nestedContent -IndentLevel $childIndent
            
            if ($nestedPanels.Count -gt 0) {
                $items += @{
                    type = 'hgroup'
                    panels = $nestedPanels
                }
            }
            
            $i = $groupEnd
            continue
        }
        # Check if this is a vertical group at current indent
        elseif ($line -match "^$indent- vgroup:\s*$") {
            # Find the extent of this group
            $groupStart = $i + 1
            $groupEnd = $groupStart
            
            # Scan ahead to find all content belonging to this group
            while ($groupEnd -lt $lines.Count) {
                $nextLine = $lines[$groupEnd]
                # Stop if we hit another item at the same indent level
                if ($nextLine -match "^$indent- " -and $groupEnd -gt $groupStart) {
                    break
                }
                $groupEnd++
            }
            
            # Extract the nested content
            $nestedContent = ($lines[$groupStart..($groupEnd-1)] -join "`n")
            
            # Detect the actual indentation of children by finding first non-empty line
            $childIndent = $IndentLevel + 2
            foreach ($childLine in ($lines[$groupStart..($groupEnd-1)])) {
                if ($childLine -match '^\s+\S') {
                    # Found first non-empty line, measure its indentation
                    $childLine -match '^(\s+)' | Out-Null
                    $childIndent = $matches[1].Length
                    break
                }
            }
            
            # Recursively parse the nested panels with detected indentation
            $nestedPanels = Parse-YamlPanels -Content $nestedContent -IndentLevel $childIndent
            
            if ($nestedPanels.Count -gt 0) {
                $items += @{
                    type = 'vgroup'
                    panels = $nestedPanels
                }
            }
            
            $i = $groupEnd
            continue
        }
        # Check if this is a regular panel definition
        elseif ($line -match "^$indent- title:\s*(.+)$") {
            $panel = @{ 
                type = 'panel'
                title = $matches[1].Trim()
                name = $matches[1].Trim()
            }
            
            # Parse panel properties
            $i++
            $propIndent = $IndentLevel + 2
            while ($i -lt $lines.Count) {
                $rawLine = $lines[$i]
                $propLine = $rawLine.TrimEnd()  # Remove trailing whitespace (CR/LF)
                
                # Properties are 2 spaces more indented than the "- title:" line
                if ($propLine -match "^\s{$propIndent}title:\s*(.+)$") {
                    $panel.title = $matches[1].Trim()
                    $panel.name = $panel.title
                }
                elseif ($propLine -match "^\s{$propIndent}url:\s*(.+)$") {
                    $panel.url = $matches[1].Trim()
                }
                elseif ($propLine -match "^\s{$propIndent}width:\s*(\S+)$") {
                    $width = $matches[1].Trim()
                    if ($width -match '^\d+$') {
                        $panel.width = [int]$width
                    }
                }
                elseif ($propLine -match "^\s{$propIndent}script:\s*(.+)$") {
                    $panel.script = $matches[1].Trim()
                }
                elseif ($propLine -match "^$indent- ") {
                    # Hit next item at same level
                    break
                }
                elseif ($propLine -eq '') {
                    # Empty line, continue
                    $i++
                    continue
                }
                else {
                    # Different indentation level
                    break
                }
                $i++
            }
            
            $items += $panel
            continue
        }
        
        $i++
    }
    
    return ,$items  # Comma prevents array unwrapping
}

function Parse-Yaml {
    param([string]$FilePath)
    
    $content = Get-Content $FilePath -Raw
    
    # Look for top-level "- hgroup:" or "- vgroup:" (0 indent)
    if ($content -notmatch '- (hgroup|vgroup):') {
        Write-Host "⚠ No '- hgroup:' or '- vgroup:' section found in config" -ForegroundColor Yellow
        return @{ panels = @() }
    }
    
    # The entire config is one top-level group, so parse from indent 0
    $topLevelItems = Parse-YamlPanels -Content $content -IndentLevel 0
    
    return @{ panels = @( @{ panels = $topLevelItems } ) }
}

$config = Parse-Yaml -FilePath $yamlPath

# XAML Definition for Main Window
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Mission Control" 
        Height="800" 
        Width="1200"
        WindowStartupLocation="CenterScreen"
        Background="#FF1E1E1E">
    <Grid Margin="0" VerticalAlignment="Stretch" HorizontalAlignment="Stretch">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        
        <!-- Menu Bar -->
        <Menu Grid.Row="0" Background="#FF2D2D30" Padding="0" Margin="0">
            <MenuItem Header="_File">
                <MenuItem Header="_Exit" Name="MenuExit"/>
            </MenuItem>
            <MenuItem Header="_Help">
                <MenuItem Header="_About" Name="MenuAbout"/>
            </MenuItem>
        </Menu>
        
        <!-- Main Content Area with Canvas for draggable panels 
             Note: Margin="0,-18,0,0" compensates for the Menu control's inherent 18px internal spacing/gap
             that appears between the menu bar and content below it, allowing panels to fill the entire area -->
        <Canvas Grid.Row="1" Name="PanelCanvas" Background="#FF252526" ClipToBounds="True" Margin="0,-18,0,0" VerticalAlignment="Stretch" HorizontalAlignment="Stretch"/>
    </Grid>
</Window>
"@

# Load XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$menuExit = $window.FindName("MenuExit")
$menuAbout = $window.FindName("MenuAbout")
$script:panelCanvas = $window.FindName("PanelCanvas")

# Function to create a draggable and resizable panel with WebView2
function New-DraggablePanel {
    param(
        [string]$Name,
        [string]$Title,
        [string]$Url,
        [double]$Left = 10,
        [double]$Top = 10,
        [double]$Width = 400,
        [double]$Height = 300
    )
    
    # Create Border (panel container)
    $border = New-Object Windows.Controls.Border
    $border.Name = "Panel_$Name"
    $border.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(255, 45, 45, 50))
    $border.BorderBrush = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(255, 100, 100, 100))
    $border.BorderThickness = New-Object Windows.Thickness(1)
    $border.CornerRadius = New-Object Windows.CornerRadius(5)
    $border.Cursor = [Windows.Input.Cursors]::Arrow
    
    # Create Grid for layout
    $grid = New-Object Windows.Controls.Grid
    $rowDef1 = New-Object Windows.Controls.RowDefinition
    $rowDef1.Height = New-Object Windows.GridLength(30, [Windows.GridUnitType]::Pixel)
    $rowDef2 = New-Object Windows.Controls.RowDefinition
    $rowDef2.Height = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $grid.RowDefinitions.Add($rowDef1)
    $grid.RowDefinitions.Add($rowDef2)
    
    # Title Bar
    $titleBar = New-Object Windows.Controls.TextBlock
    $titleBar.Text = "$Title ($([Math]::Round($Width)), $([Math]::Round($Height)))"
    $titleBar.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(255, 200, 200, 200))
    $titleBar.FontSize = 12
    $titleBar.Padding = New-Object Windows.Thickness(8, 5, 8, 5)
    $titleBar.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(255, 30, 30, 30))
    $titleBar.Cursor = [Windows.Input.Cursors]::Hand
    [Windows.Controls.Grid]::SetRow($titleBar, 0)
    [Windows.Controls.Panel]::SetZIndex($titleBar, 1000)  # Ensure title bar is always on top
    $grid.Children.Add($titleBar) | Out-Null
    
    # Store original title for updates
    $titleBar | Add-Member -NotePropertyName OriginalTitle -NotePropertyValue $Title -Force
    
    # WebView2 Frame (placeholder - will be populated by PowerShell post-creation)
    $webViewBorder = New-Object Windows.Controls.Border
    $webViewBorder.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(255, 25, 25, 26))
    $webViewBorder.Name = "WebViewContainer_$Name"
    $webViewBorder.ClipToBounds = $true
    [Windows.Controls.Grid]::SetRow($webViewBorder, 1)
    [Windows.Controls.Panel]::SetZIndex($webViewBorder, 1)  # WebView content below title bar
    $grid.Children.Add($webViewBorder) | Out-Null
    
    $border.Child = $grid
    
    # Store panel properties
    $border | Add-Member -NotePropertyName PanelName -NotePropertyValue $Name -Force
    $border | Add-Member -NotePropertyName PanelUrl -NotePropertyValue $Url -Force
    $border | Add-Member -NotePropertyName WebViewContainer -NotePropertyValue $webViewBorder -Force
    $border | Add-Member -NotePropertyName TitleBar -NotePropertyValue $titleBar -Force
    
    # Dragging logic
    $titleBar.Add_MouseLeftButtonDown({
        $wrapper = $this.Parent.Parent.Parent  # TextBlock -> Grid -> Border -> Wrapper Canvas
        
        # Bring panel to front by removing and re-adding it (last child renders on top)
        if ($script:panelCanvas.Children.Contains($wrapper)) {
            $script:panelCanvas.Children.Remove($wrapper) | Out-Null
            $script:panelCanvas.Children.Add($wrapper) | Out-Null
            Write-Host "Brought panel to front by reordering" -ForegroundColor Cyan
        }
        
        $wrapper.IsDragging = $true
        $currentLeft = [Windows.Controls.Canvas]::GetLeft($wrapper)
        $currentTop = [Windows.Controls.Canvas]::GetTop($wrapper)
        # Handle NaN values (when position not explicitly set)
        if ([Double]::IsNaN($currentLeft)) { $currentLeft = 0 }
        if ([Double]::IsNaN($currentTop)) { $currentTop = 0 }
        
        $pos = [Windows.Input.Mouse]::GetPosition($script:panelCanvas)
        $wrapper.DragStartX = $pos.X - $currentLeft
        $wrapper.DragStartY = $pos.Y - $currentTop
        $this.CaptureMouse() | Out-Null
    })
    
    $titleBar.Add_MouseMove({
        $wrapper = $this.Parent.Parent.Parent
        if ($wrapper.IsDragging) {
            $pos = [Windows.Input.Mouse]::GetPosition($script:panelCanvas)
            $newLeft = $pos.X - $wrapper.DragStartX
            $newTop = $pos.Y - $wrapper.DragStartY
            [Windows.Controls.Canvas]::SetLeft($wrapper, [Math]::Max(0, $newLeft))
            [Windows.Controls.Canvas]::SetTop($wrapper, [Math]::Max(0, $newTop))
            
            # During drag, hide WebView2s of panels we're overlapping with
            $myLeft = [Windows.Controls.Canvas]::GetLeft($wrapper)
            $myTop = [Windows.Controls.Canvas]::GetTop($wrapper)
            if ([Double]::IsNaN($myLeft)) { $myLeft = 0 }
            if ([Double]::IsNaN($myTop)) { $myTop = 0 }
            $myRight = $myLeft + $wrapper.Width
            $myBottom = $myTop + $wrapper.Height
            
            foreach ($child in $script:panelCanvas.Children) {
                if ($child -ne $wrapper -and $child.WebViewContainer) {
                    $otherLeft = [Windows.Controls.Canvas]::GetLeft($child)
                    $otherTop = [Windows.Controls.Canvas]::GetTop($child)
                    if ([Double]::IsNaN($otherLeft)) { $otherLeft = 0 }
                    if ([Double]::IsNaN($otherTop)) { $otherTop = 0 }
                    $otherRight = $otherLeft + $child.Width
                    $otherBottom = $otherTop + $child.Height
                    
                    # Check if rectangles overlap
                    $overlaps = -not ($myRight -lt $otherLeft -or $myLeft -gt $otherRight -or $myBottom -lt $otherTop -or $myTop -gt $otherBottom)
                    
                    if ($overlaps -and $child.WebViewContainer.Child) {
                        $child.WebViewContainer.Child.Visibility = [Windows.Visibility]::Hidden
                    }
                }
            }
        }
    })
    
    $titleBar.Add_MouseLeftButtonUp({
        $wrapper = $this.Parent.Parent.Parent
        $wrapper.IsDragging = $false
        $this.ReleaseMouseCapture() | Out-Null
        
        # Restore visibility of all WebView2s when drag ends
        foreach ($child in $script:panelCanvas.Children) {
            if ($child.WebViewContainer -and $child.WebViewContainer.Child) {
                $child.WebViewContainer.Child.Visibility = [Windows.Visibility]::Visible
            }
        }
    })
    
    # Add resize handle (bottom-right corner)
    $resizeHandle = New-Object Windows.Controls.TextBlock
    $resizeHandle.Text = "⇘"
    $resizeHandle.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(200, 100, 100, 100))
    $resizeHandle.FontSize = 12
    $resizeHandle.Cursor = [Windows.Input.Cursors]::SizeNWSE
    $resizeHandle.Padding = New-Object Windows.Thickness(2)
    [Windows.Controls.Canvas]::SetRight($resizeHandle, 0)
    [Windows.Controls.Canvas]::SetBottom($resizeHandle, 0)
    
    # Create wrapper canvas for the border with resize handles
    $panelWrapper = New-Object Windows.Controls.Canvas
    $panelWrapper.Width = $Width
    $panelWrapper.Height = $Height
    $panelWrapper.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(255, 45, 45, 50))
    
    # Add border to canvas
    [Windows.Controls.Canvas]::SetLeft($border, 0)
    [Windows.Controls.Canvas]::SetTop($border, 0)
    $border.Width = $Width
    $border.Height = $Height
    $panelWrapper.Children.Add($border) | Out-Null
    
    # Store properties on wrapper for dragging and access to inner elements
    $panelWrapper | Add-Member -NotePropertyName IsDragging -NotePropertyValue $false -Force
    $panelWrapper | Add-Member -NotePropertyName DragStartX -NotePropertyValue 0 -Force
    $panelWrapper | Add-Member -NotePropertyName DragStartY -NotePropertyValue 0 -Force
    $panelWrapper | Add-Member -NotePropertyName InnerBorder -NotePropertyValue $border -Force
    $panelWrapper | Add-Member -NotePropertyName TitleBar -NotePropertyValue $titleBar -Force
    
    # Add main resize handle
    $panelWrapper.Children.Add($resizeHandle) | Out-Null
    
    # Create 8 resize handles (4 edges + 4 corners)
    $resizeHandles = @(
        @{ Position = "TopLeft"; Cursor = [Windows.Input.Cursors]::SizeNWSE; Text = ""; Width = 8; Height = 8; Left = 0; Top = 0 }
        @{ Position = "Top"; Cursor = [Windows.Input.Cursors]::SizeNS; Text = ""; Width = "full"; Height = 4; Left = 0; Top = 0 }
        @{ Position = "TopRight"; Cursor = [Windows.Input.Cursors]::SizeNESW; Text = ""; Width = 8; Height = 8; Right = 0; Top = 0 }
        @{ Position = "Right"; Cursor = [Windows.Input.Cursors]::SizeWE; Text = ""; Width = 4; Height = "full"; Right = 0; Top = 0 }
        @{ Position = "BottomRight"; Cursor = [Windows.Input.Cursors]::SizeNWSE; Text = "⇘"; Width = 16; Height = 16; Right = 0; Bottom = 0 }
        @{ Position = "Bottom"; Cursor = [Windows.Input.Cursors]::SizeNS; Text = ""; Width = "full"; Height = 4; Left = 0; Bottom = 0 }
        @{ Position = "BottomLeft"; Cursor = [Windows.Input.Cursors]::SizeNESW; Text = ""; Width = 8; Height = 8; Left = 0; Bottom = 0 }
        @{ Position = "Left"; Cursor = [Windows.Input.Cursors]::SizeWE; Text = ""; Width = 4; Height = "full"; Left = 0; Top = 0 }
    )
    
    $edgeHandles = @()
    
    foreach ($handleDef in $resizeHandles) {
        $handle = New-Object Windows.Controls.Border
        $handle.Background = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(0, 0, 0, 0))
        $handle.Cursor = $handleDef.Cursor
        
        # Set dimensions - "full" means it spans the entire width or height
        if ($handleDef.Width -eq "full") { 
            $handle.Width = $Width
        } else { 
            $handle.Width = $handleDef.Width 
        }
        
        if ($handleDef.Height -eq "full") { 
            $handle.Height = $Height
        } else { 
            $handle.Height = $handleDef.Height 
        }
        
        if ($handleDef.ContainsKey("Left")) { [Windows.Controls.Canvas]::SetLeft($handle, $handleDef.Left) }
        if ($handleDef.ContainsKey("Top")) { [Windows.Controls.Canvas]::SetTop($handle, $handleDef.Top) }
        if ($handleDef.ContainsKey("Right")) { [Windows.Controls.Canvas]::SetRight($handle, $handleDef.Right) }
        if ($handleDef.ContainsKey("Bottom")) { [Windows.Controls.Canvas]::SetBottom($handle, $handleDef.Bottom) }
        
        $handle | Add-Member -NotePropertyName ResizePosition -NotePropertyValue $handleDef.Position -Force
        $handle | Add-Member -NotePropertyName IsEdgeHandle -NotePropertyValue ($handleDef.Width -eq "full" -or $handleDef.Height -eq "full") -Force
        
        # Resize event handlers
        $handle.Add_MouseLeftButtonDown({
            $wrapper = $this.Parent
            $wrapper.IsResizing = $true
            $wrapper.ResizePosition = $this.ResizePosition
            $wrapper.ResizeStartWidth = $wrapper.Width
            $wrapper.ResizeStartHeight = $wrapper.Height
            $wrapper.ResizeStartLeft = [Windows.Controls.Canvas]::GetLeft($wrapper)
            $wrapper.ResizeStartTop = [Windows.Controls.Canvas]::GetTop($wrapper)
            $pos = [Windows.Input.Mouse]::GetPosition($script:panelCanvas)
            $wrapper.ResizeStartX = $pos.X
            $wrapper.ResizeStartY = $pos.Y
            $this.CaptureMouse() | Out-Null
        })
        
        $handle.Add_MouseMove({
            $wrapper = $this.Parent
            if ($wrapper.IsResizing) {
                $pos = [Windows.Input.Mouse]::GetPosition($script:panelCanvas)
                $deltaX = $pos.X - $wrapper.ResizeStartX
                $deltaY = $pos.Y - $wrapper.ResizeStartY
                
                $newWidth = $wrapper.ResizeStartWidth
                $newHeight = $wrapper.ResizeStartHeight
                $newLeft = $wrapper.ResizeStartLeft
                $newTop = $wrapper.ResizeStartTop
                
                switch ($wrapper.ResizePosition) {
                    "TopLeft" {
                        $newWidth = [Math]::Max(200, $wrapper.ResizeStartWidth - $deltaX)
                        $newHeight = [Math]::Max(150, $wrapper.ResizeStartHeight - $deltaY)
                        $newLeft = $wrapper.ResizeStartLeft + ($wrapper.ResizeStartWidth - $newWidth)
                        $newTop = $wrapper.ResizeStartTop + ($wrapper.ResizeStartHeight - $newHeight)
                    }
                    "Top" {
                        $newHeight = [Math]::Max(150, $wrapper.ResizeStartHeight - $deltaY)
                        $newTop = $wrapper.ResizeStartTop + ($wrapper.ResizeStartHeight - $newHeight)
                    }
                    "TopRight" {
                        $newWidth = [Math]::Max(200, $wrapper.ResizeStartWidth + $deltaX)
                        $newHeight = [Math]::Max(150, $wrapper.ResizeStartHeight - $deltaY)
                        $newTop = $wrapper.ResizeStartTop + ($wrapper.ResizeStartHeight - $newHeight)
                    }
                    "Right" {
                        $newWidth = [Math]::Max(200, $wrapper.ResizeStartWidth + $deltaX)
                    }
                    "BottomRight" {
                        $newWidth = [Math]::Max(200, $wrapper.ResizeStartWidth + $deltaX)
                        $newHeight = [Math]::Max(150, $wrapper.ResizeStartHeight + $deltaY)
                    }
                    "Bottom" {
                        $newHeight = [Math]::Max(150, $wrapper.ResizeStartHeight + $deltaY)
                    }
                    "BottomLeft" {
                        $newWidth = [Math]::Max(200, $wrapper.ResizeStartWidth - $deltaX)
                        $newHeight = [Math]::Max(150, $wrapper.ResizeStartHeight + $deltaY)
                        $newLeft = $wrapper.ResizeStartLeft + ($wrapper.ResizeStartWidth - $newWidth)
                    }
                    "Left" {
                        $newWidth = [Math]::Max(200, $wrapper.ResizeStartWidth - $deltaX)
                        $newLeft = $wrapper.ResizeStartLeft + ($wrapper.ResizeStartWidth - $newWidth)
                    }
                }
                
                $wrapper.Width = $newWidth
                $wrapper.Height = $newHeight
                $wrapper.InnerBorder.Width = $newWidth
                $wrapper.InnerBorder.Height = $newHeight
                [Windows.Controls.Canvas]::SetLeft($wrapper, $newLeft)
                [Windows.Controls.Canvas]::SetTop($wrapper, $newTop)
                
                # Update title bar with new dimensions
                if ($wrapper.TitleBar) {
                    $wrapper.TitleBar.Text = "$($wrapper.TitleBar.OriginalTitle) ($([Math]::Round($newWidth)), $([Math]::Round($newHeight)))"
                }
                
                # Update edge handle sizes
                foreach ($child in $wrapper.Children) {
                    if ($child.IsEdgeHandle) {
                        switch ($child.ResizePosition) {
                            { $_ -in @("Top", "Bottom") } { $child.Width = $newWidth }
                            { $_ -in @("Left", "Right") } { $child.Height = $newHeight }
                        }
                    }
                }
            }
        })
        
        $handle.Add_MouseLeftButtonUp({
            $wrapper = $this.Parent
            $wrapper.IsResizing = $false
            $this.ReleaseMouseCapture() | Out-Null
        })
        
        $panelWrapper.Children.Add($handle) | Out-Null
        
        # Store edge handles for later updates
        if ($handle.IsEdgeHandle) {
            $edgeHandles += $handle
        }
    }
    
    # Store edge handles reference on wrapper
    $panelWrapper | Add-Member -NotePropertyName EdgeHandles -NotePropertyValue $edgeHandles -Force
    
    # Store resize state on the wrapper
    $panelWrapper | Add-Member -NotePropertyName IsResizing -NotePropertyValue $false -Force
    $panelWrapper | Add-Member -NotePropertyName ResizePosition -NotePropertyValue "" -Force
    $panelWrapper | Add-Member -NotePropertyName ResizeStartWidth -NotePropertyValue $Width -Force
    $panelWrapper | Add-Member -NotePropertyName ResizeStartHeight -NotePropertyValue $Height -Force
    $panelWrapper | Add-Member -NotePropertyName ResizeStartLeft -NotePropertyValue 0 -Force
    $panelWrapper | Add-Member -NotePropertyName ResizeStartTop -NotePropertyValue 0 -Force
    $panelWrapper | Add-Member -NotePropertyName ResizeStartX -NotePropertyValue 0 -Force
    $panelWrapper | Add-Member -NotePropertyName ResizeStartY -NotePropertyValue 0 -Force
    $panelWrapper | Add-Member -NotePropertyName PanelName -NotePropertyValue $Name -Force
    $panelWrapper | Add-Member -NotePropertyName PanelUrl -NotePropertyValue $Url -Force
    $panelWrapper | Add-Member -NotePropertyName InnerBorder -NotePropertyValue $border -Force
    $panelWrapper | Add-Member -NotePropertyName WebViewContainer -NotePropertyValue $webViewBorder -Force
    
    [Windows.Controls.Canvas]::SetLeft($panelWrapper, $Left)
    [Windows.Controls.Canvas]::SetTop($panelWrapper, $Top)
    
    return $panelWrapper
}

# Recursive function to create panels or groups
function Create-PanelOrGroup {
    param(
        [hashtable]$Item,
        [double]$Left,
        [double]$Top,
        [double]$Width,
        [double]$Height,
        [int]$GridRow = 0,
        [int]$GridCol = 0
    )
    
    if (-not $Item) {
        Write-Host "WARNING: Create-PanelOrGroup received null item" -ForegroundColor Red
        return $null
    }
    
    if ($Item.type -eq 'hgroup') {
        
        # Create a container for the group
        $groupContainer = New-Object Windows.Controls.Canvas
        $groupContainer.Width = $Width
        $groupContainer.Height = $Height
        $groupContainer.Background = [Windows.Media.Brushes]::Transparent
        $groupContainer | Add-Member -NotePropertyName PanelName -NotePropertyValue "hgroup_$GridRow_$GridCol" -Force
        $groupContainer | Add-Member -NotePropertyName IsGroup -NotePropertyValue $true -Force
        $groupContainer | Add-Member -NotePropertyName GridRow -NotePropertyValue $GridRow -Force
        $groupContainer | Add-Member -NotePropertyName GridColumn -NotePropertyValue $GridCol -Force
        
        # Arrange children horizontally within the group
        $childCount = $Item.panels.Count
        $childWidth = $Width / $childCount
        $childLeft = 0
        
        for ($i = 0; $i -lt $childCount; $i++) {
            $child = $Item.panels[$i]
            if (-not $child) {
                Write-Host "WARNING: Child $i is null, skipping" -ForegroundColor Red
                continue
            }
            $childControl = Create-PanelOrGroup -Item $child -Left $childLeft -Top 0 -Width $childWidth -Height $Height -GridRow 0 -GridCol $i
            if ($childControl) {
                $groupContainer.Children.Add($childControl) | Out-Null
            }
            $childLeft += $childWidth
        }
        
        [Windows.Controls.Canvas]::SetLeft($groupContainer, $Left)
        [Windows.Controls.Canvas]::SetTop($groupContainer, $Top)
        
        # Add SizeChanged handler to resize children horizontally
        $groupContainer.Add_SizeChanged({
            try {
                $container = $this
                $childCount = $container.Children.Count
                if ($childCount -gt 0 -and $container.ActualWidth -gt 0) {
                    $childWidth = $container.ActualWidth / $childCount
                    $childLeft = 0
                    foreach ($childControl in $container.Children) {
                        $childControl.Width = $childWidth
                        $childControl.Height = $container.ActualHeight
                        [Windows.Controls.Canvas]::SetLeft($childControl, $childLeft)
                        [Windows.Controls.Canvas]::SetTop($childControl, 0)
                        $childLeft += $childWidth
                    }
                }
            }
            catch { }
        })
        
        return $groupContainer
    }
    elseif ($Item.type -eq 'vgroup') {
        
        # Create a container for the group
        $groupContainer = New-Object Windows.Controls.Canvas
        $groupContainer.Width = $Width
        $groupContainer.Height = $Height
        $groupContainer.Background = [Windows.Media.Brushes]::Transparent
        $groupContainer | Add-Member -NotePropertyName PanelName -NotePropertyValue "vgroup_$GridRow_$GridCol" -Force
        $groupContainer | Add-Member -NotePropertyName IsGroup -NotePropertyValue $true -Force
        $groupContainer | Add-Member -NotePropertyName GridRow -NotePropertyValue $GridRow -Force
        $groupContainer | Add-Member -NotePropertyName GridColumn -NotePropertyValue $GridCol -Force
        
        # Arrange children vertically within the group
        $childCount = $Item.panels.Count
        $childHeight = $Height / $childCount
        $childTop = 0
        
        for ($i = 0; $i -lt $childCount; $i++) {
            $child = $Item.panels[$i]
            if (-not $child) {
                Write-Host "WARNING: Child $i is null, skipping" -ForegroundColor Red
                continue
            }
            $childControl = Create-PanelOrGroup -Item $child -Left 0 -Top $childTop -Width $Width -Height $childHeight -GridRow $i -GridCol 0
            if ($childControl) {
                $groupContainer.Children.Add($childControl) | Out-Null
            }
            $childTop += $childHeight
        }
        
        [Windows.Controls.Canvas]::SetLeft($groupContainer, $Left)
        [Windows.Controls.Canvas]::SetTop($groupContainer, $Top)
        
        # Add SizeChanged handler to resize children vertically
        $groupContainer.Add_SizeChanged({
            try {
                $container = $this
                $childCount = $container.Children.Count
                if ($childCount -gt 0 -and $container.ActualHeight -gt 0) {
                    $childHeight = $container.ActualHeight / $childCount
                    $childTop = 0
                    foreach ($childControl in $container.Children) {
                        $childControl.Width = $container.ActualWidth
                        $childControl.Height = $childHeight
                        [Windows.Controls.Canvas]::SetLeft($childControl, 0)
                        [Windows.Controls.Canvas]::SetTop($childControl, $childTop)
                        $childTop += $childHeight
                    }
                }
            }
            catch { }
        })
        
        return $groupContainer
    }
    else {
        # Create a regular panel (sanitize Name for WPF control naming rules)
        $rawName = if ([string]::IsNullOrWhiteSpace($Item.name)) { 'panel' } else { $Item.name }
        $safeName = $rawName -replace "[^A-Za-z0-9_]", '_' 
        if ($safeName -match '^[0-9]') { $safeName = "Panel_$safeName" }
        $panelControl = New-DraggablePanel -Name $safeName -Title $Item.title -Url $Item.url -Left $Left -Top $Top -Width $Width -Height $Height
        
        # Store panel properties
        $panelControl | Add-Member -NotePropertyName GridRow -NotePropertyValue $GridRow -Force
        $panelControl | Add-Member -NotePropertyName GridColumn -NotePropertyValue $GridCol -Force
        $panelControl | Add-Member -NotePropertyName ConfigWidth -NotePropertyValue $(if ($Item.ContainsKey('width')) { $Item.width } else { $null }) -Force
        $panelControl | Add-Member -NotePropertyName ScriptPath -NotePropertyValue $(if ($Item.ContainsKey('script')) { $Item.script } else { $null }) -Force
        $script:allPanels += $panelControl
        
        # Create and add WebView2 control
        try {
            if (-not $script:webView2Available) {
                throw "WebView2 runtime not available"
            }
            
            $webView = New-Object Microsoft.Web.WebView2.Wpf.WebView2
            $webView.HorizontalAlignment = [Windows.HorizontalAlignment]::Stretch
            $webView.VerticalAlignment = [Windows.VerticalAlignment]::Stretch
            $webView.Tag = $nameForStore
            
            # Add WebView2 to the container
            $container = $panelControl.InnerBorder.Child.Children[1]
            $container.Child = $webView
            
            # Store for later initialization
            $scriptPath = if ($Item.ContainsKey('script')) { $Item.script } else { $null }
            $nameForStore = if ([string]::IsNullOrWhiteSpace($Item.name)) { 'panel' } else { $Item.name }
            $script:webViewsToInitialize += @{
                WebView = $webView
                Url = $Item.url
                Name = $nameForStore
                ScriptPath = $scriptPath
            }
            
            Write-Host "✓ Created WebView2 panel for $($Item.name): $($Item.url)" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠ Failed to create WebView2 for $($Item.name): $_" -ForegroundColor Yellow
        }
        
        # Add SizeChanged handler to resize panel content
        $panelControl.Add_SizeChanged({
            try {
                $panel = $this
                if ($panel.InnerBorder) {
                    $panel.InnerBorder.Width = $panel.ActualWidth
                    $panel.InnerBorder.Height = $panel.ActualHeight
                }
            }
            catch { }
        })
        
        return $panelControl
    }
}

# Create panels from config
$script:webViewsToInitialize = @()
$script:allPanels = @()

# The config.panels contains one wrapper object with the top-level layout item
if ($config.panels.Count -gt 0 -and $config.panels[0].panels.Count -gt 0) {
    $topLevelItem = $config.panels[0].panels[0]
    # Create the top-level control which will be the entire canvas
    $control = Create-PanelOrGroup -Item $topLevelItem -Left 0 -Top 0 -Width 1185 -Height 763 -GridRow 0 -GridCol 0
    if ($control) {
        $script:panelCanvas.Children.Add($control) | Out-Null
    }
}

Write-Host "✓ Created $($script:allPanels.Count) panels" -ForegroundColor Green
Write-Host "✓ Queued $($script:webViewsToInitialize.Count) WebView2 controls for initialization" -ForegroundColor Green

# Initialize WebView2 controls after window is loaded
$window.Add_ContentRendered({
    # Set the top-level control to fill the canvas
    if ($script:panelCanvas.Children.Count -gt 0) {
        $topControl = $script:panelCanvas.Children[0]
        $topControl.Width = $script:panelCanvas.ActualWidth
        $topControl.Height = $script:panelCanvas.ActualHeight
        [Windows.Controls.Canvas]::SetLeft($topControl, 0)
        [Windows.Controls.Canvas]::SetTop($topControl, 0)
        
        Write-Host "Canvas dimensions: $($script:panelCanvas.ActualWidth) x $($script:panelCanvas.ActualHeight)" -ForegroundColor Yellow
    }
    
    # Create shared user data folder for WebView2 in project root
    $userDataFolder = Join-Path $ScriptDirectory ".webview2"
    if (-not (Test-Path $userDataFolder)) {
        New-Item -ItemType Directory -Path $userDataFolder -Force | Out-Null
        Write-Host "✓ Created WebView2 data folder: $userDataFolder" -ForegroundColor Green
    }
    
    # Handle window resize - resize top-level control to fill canvas
    $script:panelCanvas.Add_SizeChanged({
        try {
            if ($script:panelCanvas.Children.Count -gt 0) {
                $topControl = $script:panelCanvas.Children[0]
                $newWidth = $script:panelCanvas.ActualWidth
                $newHeight = $script:panelCanvas.ActualHeight
                
                if ($newWidth -gt 0 -and $newHeight -gt 0) {
                    $topControl.Width = $newWidth
                    $topControl.Height = $newHeight
                }
            }
        }
        catch {
            Write-Host "Error in SizeChanged: $_" -ForegroundColor Red
        }
    })
    
    # Capture variables for async closures
    $webViewList = $script:webViewsToInitialize
    $scriptDir = $ScriptDirectory
    
    # Initialize WebView2 environment asynchronously without blocking
    Write-Host "Creating WebView2 environment..." -ForegroundColor Cyan
    
    $envTask = [Microsoft.Web.WebView2.Core.CoreWebView2Environment]::CreateAsync($null, $userDataFolder, $null)
    
    # Set up async completion handler - this will run when environment is ready
    $envTask.GetAwaiter().OnCompleted({
        try {
            $sharedEnv = $envTask.GetAwaiter().GetResult()
            Write-Host "✓ WebView2 environment ready" -ForegroundColor Green
            
            # Initialize each WebView2 control
            foreach ($item in $webViewList) {
                $webView = $item['WebView']
                $url = $item['Url']
                $name = $item['Name']
                $scriptPath = $item['ScriptPath']
                
                # Read script content now if configured
                $scriptContent = $null
                if ($scriptPath) {
                    $fullScriptPath = Join-Path $scriptDir $scriptPath
                    if (Test-Path $fullScriptPath) {
                        $scriptContent = Get-Content $fullScriptPath -Raw
                        Write-Host "✓ Loaded script for $name : $scriptPath ($($scriptContent.Length) chars)" -ForegroundColor Cyan
                    } else {
                        Write-Host "⚠ Script file not found for $name : $fullScriptPath" -ForegroundColor Yellow
                    }
                }
                
                try {
                    # Use shared environment
                    $initTask = $webView.EnsureCoreWebView2Async($sharedEnv)
                    
                    # Create closure variables
                    $localWebView = $webView
                    $localUrl = $url
                    $localName = if ([string]::IsNullOrWhiteSpace($name)) { 'panel' } else { $name }
                    $localScript = $scriptContent
                    $localInjectLog = "✓ Injected script for $localName"
                    
                    # Set up completion handler
                    $initTask.GetAwaiter().OnCompleted({
                        try {
                            # If a script is loaded, set up event handler
                            if ($localScript) {
                                $localWebView.add_NavigationCompleted({
                                    param($sender, $args)
                                    try {
                                        # Log on the UI thread so it actually prints to host
                                        Write-Host $localInjectLog -ForegroundColor Magenta
                                        $sender.CoreWebView2.ExecuteScriptAsync($localScript) | Out-Null
                                    }
                                    catch {
                                        Write-Host "⚠ Failed to inject script for $localName : $_" -ForegroundColor Yellow
                                    }
                                })
                            }
                            
                            # Navigate to URL
                            $localWebView.Source = [System.Uri]::new($localUrl)
                            Write-Host "✓ Navigated $localName to $localUrl" -ForegroundColor Cyan
                        }
                        catch {
                            Write-Host "⚠ Failed to navigate $localName : $_" -ForegroundColor Yellow
                        }
                    }.GetNewClosure())
                }
                catch {
                    Write-Host "⚠ Failed to initialize WebView2 for $name : $_" -ForegroundColor Yellow
                }
            }
        }
        catch {
            Write-Host "⚠ Failed to create WebView2 environment: $_" -ForegroundColor Yellow
        }
    }.GetNewClosure())
})

# Handle window resizing
$window.Add_SizeChanged({
    $canvasWidth = $script:panelCanvas.ActualWidth
    $canvasHeight = $script:panelCanvas.ActualHeight
    
    if ($canvasWidth -gt 0 -and $canvasHeight -gt 0) {
        # Calculate dimensions based on rows
        $numRows = $script:rows.Count
        $panelH = $canvasHeight / $numRows
        
        # Process each row to calculate positions and handle custom widths
        foreach ($rowInfo in $script:rows) {
            $rowControls = $rowInfo.controls
            $leftOffset = 0
            
            foreach ($control in $rowControls) {
                # Use configured width or calculate proportional width
                if ($control.ConfigWidth -ne $null) {
                    $panelW = $control.ConfigWidth
                } else {
                    # Calculate remaining width for controls without explicit width
                    $totalConfiguredWidth = ($rowControls | Where-Object { $_.ConfigWidth -ne $null } | ForEach-Object { $_.ConfigWidth } | Measure-Object -Sum).Sum
                    $controlsWithoutWidth = ($rowControls | Where-Object { $_.ConfigWidth -eq $null }).Count
                    if ($controlsWithoutWidth -gt 0) {
                        $panelW = ($canvasWidth - $totalConfiguredWidth) / $controlsWithoutWidth
                    } else {
                        $panelW = $canvasWidth / $rowControls.Count
                    }
                }
                
                $control.Width = $panelW
                $control.Height = $panelH
                if ($control.InnerBorder) {
                    $control.InnerBorder.Width = $panelW
                    $control.InnerBorder.Height = $panelH
                }
                
                [Windows.Controls.Canvas]::SetLeft($control, $leftOffset)
                [Windows.Controls.Canvas]::SetTop($control, $control.GridRow * $panelH)
                
                # Update title bar with new dimensions (only for panels, not groups)
                if ($control.TitleBar) {
                    $control.TitleBar.Text = "$($control.TitleBar.OriginalTitle) ($([Math]::Round($panelW)), $([Math]::Round($panelH)))"
                }
                
                Write-Host "Control $($control.PanelName): Position ($leftOffset, $topPos), Size ($panelW x $panelH)" -ForegroundColor Gray
                
                $leftOffset += $panelW
            }
        }
    }
})

# Event Handlers
$menuExit.Add_Click({
    $window.Close()
})

$menuAbout.Add_Click({
    [System.Windows.MessageBox]::Show(
        "Mission Control v0.1.0`n`nA PowerShell WPF application with multiple WebView2 controls.",
        "About Mission Control",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )
})

# Show the window
$window.ShowDialog() | Out-Null

}
catch {
    Write-Host "`n❌ FATAL ERROR: $_" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    # Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
    # $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
