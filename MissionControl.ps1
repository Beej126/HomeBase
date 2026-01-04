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

# Simple YAML parser for nested group definitions
function Parse-Yaml {
    param([string]$FilePath)
    
    $config = @{ groups = @() }
    $content = Get-Content $FilePath -Raw
    
    # Parse groups - simplified to just look for "- panels:" markers
    $groupPattern = '- panels:'
    $groupMatches = [regex]::Matches($content, $groupPattern)
    
    $groupIndex = 0
    foreach ($groupMatch in $groupMatches) {
        $groupStartIndex = $groupMatch.Index + $groupMatch.Length
        
        # Find the next group or end of file
        $nextGroupIndex = $content.Length
        $nextMatch = [regex]::Match($content.Substring($groupStartIndex), '^\s*- panels:', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        if ($nextMatch.Success) {
            $nextGroupIndex = $groupStartIndex + $nextMatch.Index
        }
        
        $groupContent = $content.Substring($groupStartIndex, $nextGroupIndex - $groupStartIndex)
        
        Write-Host "DEBUG: Group content length: $($groupContent.Length)" -ForegroundColor Gray
        Write-Host "DEBUG: Group content preview: $($groupContent.Substring(0, [Math]::Min(200, $groupContent.Length)))" -ForegroundColor Gray
        
        # Parse panels by splitting on panel list items
        $panelLines = $groupContent -split "`n" | Where-Object { $_.Trim() -ne '' }
        $panels = @()
        $currentPanel = $null
        
        foreach ($line in $panelLines) {
            if ($line -match '^\s+- name:\s*(.+)$') {
                # Start of new panel
                if ($currentPanel) {
                    $panels += $currentPanel
                }
                $currentPanel = @{ name = $matches[1].Trim() }
            }
            elseif ($currentPanel -and $line -match '^\s+title:\s*(.+)$') {
                $currentPanel.title = $matches[1].Trim()
            }
            elseif ($currentPanel -and $line -match '^\s+url:\s*(.+)$') {
                $currentPanel.url = $matches[1].Trim()
            }
            elseif ($currentPanel -and $line -match '^\s+width:\s*(\d+)$') {
                $currentPanel.width = [int]$matches[1].Trim()
            }
            elseif ($currentPanel -and $line -match '^\s+script:\s*(.+)$') {
                $currentPanel.script = $matches[1].Trim()
            }
        }
        # Don't forget last panel
        if ($currentPanel) {
            $panels += $currentPanel
        }
        
        Write-Host "DEBUG: Parsed $($panels.Count) panels" -ForegroundColor Gray
        
        $group = @{
            panels = $panels
        }
        $config.groups += $group
        $groupIndex++
    }
    
    return $config
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
        $script:panelCanvas.Children.Remove($wrapper)
        $script:panelCanvas.Children.Add($wrapper) | Out-Null
        
        Write-Host "Brought panel to front by reordering" -ForegroundColor Cyan
        
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

# Create panels from config groups
$script:webViewsToInitialize = @()
$script:allPanels = @()
$script:groups = @()

# Initial size - will be updated after window loads
$panelWidth = 600
$panelHeight = 387

$groupRow = 0
foreach ($group in $config.groups) {
    $groupInfo = @{
        row = $groupRow
        panels = @()
    }
    
    $col = 0
    $groupLeftOffset = 0
    foreach ($panel in $group.panels) {
        # Use specified width or default
        $thisWidth = if ($panel.ContainsKey('width')) { $panel.width } else { $panelWidth }
        
        $top = $groupRow * $panelHeight
        $left = $groupLeftOffset
        
        $panelControl = New-DraggablePanel -Name $panel.name -Title $panel.title -Url $panel.url -Left $left -Top $top -Width $thisWidth -Height $panelHeight
        
        # Store panel with grid position and custom width for later resizing
        $panelControl | Add-Member -NotePropertyName GridRow -NotePropertyValue $groupRow -Force
        $panelControl | Add-Member -NotePropertyName GridColumn -NotePropertyValue $col -Force
        $panelControl | Add-Member -NotePropertyName ConfigWidth -NotePropertyValue $(if ($panel.ContainsKey('width')) { $panel.width } else { $null }) -Force
        $panelControl | Add-Member -NotePropertyName ScriptPath -NotePropertyValue $(if ($panel.ContainsKey('script')) { $panel.script } else { $null }) -Force
        $script:allPanels += $panelControl
        $groupInfo.panels += $panelControl
        
        $groupLeftOffset += $thisWidth
        $col += 1
        
        # Create and add WebView2 control
        try {
            if (-not $script:webView2Available) {
                throw "WebView2 runtime not available. Please install from https://developer.microsoft.com/en-us/microsoft-edge/webview2/"
            }
            
            $webView = New-Object Microsoft.Web.WebView2.Wpf.WebView2
            $webView.HorizontalAlignment = [Windows.HorizontalAlignment]::Stretch
            $webView.VerticalAlignment = [Windows.VerticalAlignment]::Stretch
            
            # Add WebView2 to the container first (must be in visual tree before initialization)
            $container = $panelControl.InnerBorder.Child.Children[1]  # Get WebViewContainer from Grid
            $container.Child = $webView
            
            # Store for later initialization (after window is loaded)
            $script:webViewsToInitialize += @{
                WebView = $webView
                Url = $panel.url
                Name = $panel.name
                ScriptPath = $(if ($panel.ContainsKey('script')) { $panel.script } else { $null })
            }
            
            Write-Host "✓ Created WebView2 panel for $($panel.name): $($panel.url)" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠ Failed to create WebView2 for $($panel.name): $_" -ForegroundColor Yellow
            # Create fallback text block
            $fallback = New-Object Windows.Controls.TextBlock
            $fallback.Text = "WebView2 Error:`n$_`n`nURL: $($panel.url)"
            $fallback.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(255, 200, 100, 100))
            $fallback.TextWrapping = [Windows.TextWrapping]::Wrap
            $fallback.Padding = New-Object Windows.Thickness(10)
            $fallback.FontSize = 11
            $container = $panelControl.InnerBorder.Child.Children[1]
            $container.Child = $fallback
        }
        
        $script:panelCanvas.Children.Add($panelControl) | Out-Null
        $col += 1
    }
    
    $groupInfo | Add-Member -NotePropertyName ColumnCount -NotePropertyValue $col -Force
    $script:groups += $groupInfo
    $groupRow += 1
}

Write-Host "✓ Created $($script:allPanels.Count) panels in $($script:groups.Count) groups" -ForegroundColor Green
Write-Host "✓ Queued $($script:webViewsToInitialize.Count) WebView2 controls for initialization" -ForegroundColor Green

# Initialize WebView2 controls after window is loaded
$window.Add_ContentRendered({
    # Calculate and set panel sizes to fill window
    $canvasWidth = $script:panelCanvas.ActualWidth
    $canvasHeight = $script:panelCanvas.ActualHeight
    
    Write-Host "Canvas dimensions: $canvasWidth x $canvasHeight" -ForegroundColor Yellow
    
    # Calculate dimensions based on groups
    $numGroups = $script:groups.Count
    $panelH = $canvasHeight / $numGroups
    
    Write-Host "Panel height: $panelH (Groups: $numGroups)" -ForegroundColor Yellow
    
    # Process each group to calculate positions and handle custom widths
    foreach ($groupInfo in $script:groups) {
        $groupPanels = $groupInfo.panels
        $leftOffset = 0
        
        foreach ($panel in $groupPanels) {
            # Use configured width or calculate proportional width
            if ($panel.ConfigWidth -ne $null) {
                $panelW = $panel.ConfigWidth
            } else {
                # Calculate remaining width for panels without explicit width
                $totalConfiguredWidth = ($groupPanels | Where-Object { $_.ConfigWidth -ne $null } | ForEach-Object { $_.ConfigWidth } | Measure-Object -Sum).Sum
                $panelsWithoutWidth = ($groupPanels | Where-Object { $_.ConfigWidth -eq $null }).Count
                if ($panelsWithoutWidth -gt 0) {
                    $panelW = ($canvasWidth - $totalConfiguredWidth) / $panelsWithoutWidth
                } else {
                    $panelW = $canvasWidth / $groupPanels.Count
                }
            }
            
            $panel.Width = $panelW
            $panel.Height = $panelH
            $panel.InnerBorder.Width = $panelW
            $panel.InnerBorder.Height = $panelH
            
            $topPos = $panel.GridRow * $panelH
            
            [Windows.Controls.Canvas]::SetLeft($panel, $leftOffset)
            [Windows.Controls.Canvas]::SetTop($panel, $topPos)
            
            # Update title bar with initial dimensions
            if ($panel.TitleBar) {
                $panel.TitleBar.Text = "$($panel.TitleBar.OriginalTitle) ($([Math]::Round($panelW)), $([Math]::Round($panelH)))"
            }
            
            Write-Host "Panel $($panel.PanelName): Position ($leftOffset, $topPos), Size ($panelW x $panelH)" -ForegroundColor Gray
            
            $leftOffset += $panelW
        }
    }
    
    # Create shared user data folder for WebView2 in project root
    $userDataFolder = Join-Path $ScriptDirectory ".webview2"
    if (-not (Test-Path $userDataFolder)) {
        New-Item -ItemType Directory -Path $userDataFolder -Force | Out-Null
        Write-Host "✓ Created WebView2 data folder: $userDataFolder" -ForegroundColor Green
    }
    
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
            Write-Host "DEBUG: Starting panel initialization, count=$($webViewList.Count)" -ForegroundColor Gray
            
            # Initialize each WebView2 control
            foreach ($item in $webViewList) {
                $webView = $item.WebView
                $url = $item.Url
                $name = $item.Name
                $scriptPath = $item.ScriptPath
                
                Write-Host "DEBUG: Processing $name, scriptPath='$scriptPath'" -ForegroundColor Gray
                
                # Read script content now if configured
                $scriptContent = $null
                if ($scriptPath) {
                    $fullScriptPath = Join-Path $scriptDir $scriptPath
                    Write-Host "DEBUG: Full script path: $fullScriptPath" -ForegroundColor Gray
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
                    $localName = $name
                    $localScript = $scriptContent
                    
                    # Set up completion handler
                    $initTask.GetAwaiter().OnCompleted({
                        try {
                            # If a script is loaded, set up event handler
                            if ($localScript) {
                                $localWebView.add_NavigationCompleted({
                                    param($sender, $args)
                                    try {
                                        $sender.CoreWebView2.ExecuteScriptAsync($localScript).GetAwaiter().OnCompleted({
                                            Write-Host "✓ Injected script for $localName" -ForegroundColor Magenta
                                        }.GetNewClosure())
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
        # Calculate dimensions based on groups
        $numGroups = $script:groups.Count
        $panelH = $canvasHeight / $numGroups
        
        # Process each group to calculate positions and handle custom widths
        foreach ($groupInfo in $script:groups) {
            $groupPanels = $groupInfo.panels
            $leftOffset = 0
            
            foreach ($panel in $groupPanels) {
                # Use configured width or calculate proportional width
                if ($panel.ConfigWidth -ne $null) {
                    $panelW = $panel.ConfigWidth
                } else {
                    # Calculate remaining width for panels without explicit width
                    $totalConfiguredWidth = ($groupPanels | Where-Object { $_.ConfigWidth -ne $null } | ForEach-Object { $_.ConfigWidth } | Measure-Object -Sum).Sum
                    $panelsWithoutWidth = ($groupPanels | Where-Object { $_.ConfigWidth -eq $null }).Count
                    if ($panelsWithoutWidth -gt 0) {
                        $panelW = ($canvasWidth - $totalConfiguredWidth) / $panelsWithoutWidth
                    } else {
                        $panelW = $canvasWidth / $groupPanels.Count
                    }
                }
                
                $panel.Width = $panelW
                $panel.Height = $panelH
                $panel.InnerBorder.Width = $panelW
                $panel.InnerBorder.Height = $panelH
                
                [Windows.Controls.Canvas]::SetLeft($panel, $leftOffset)
                [Windows.Controls.Canvas]::SetTop($panel, $panel.GridRow * $panelH)
                
                # Update title bar with new dimensions
                if ($panel.TitleBar) {
                    $panel.TitleBar.Text = "$($panel.TitleBar.OriginalTitle) ($([Math]::Round($panelW)), $([Math]::Round($panelH)))"
                }
                
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
    Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
