# Watcher script for MissionControl.ps1 and config.yml
# Restarts MissionControl.ps1 whenever either file changes

param(
    [string]$TargetScript = "MissionControl-WPF.ps1",
    [string]$ConfigFile = "config.yml"
)

$scriptPath = Join-Path $PSScriptRoot $TargetScript
$configPath = Join-Path $PSScriptRoot $ConfigFile

# Verify files exist
if (-not (Test-Path $scriptPath)) {
    Write-Host "❌ Target script not found: $scriptPath" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $configPath)) {
    Write-Host "❌ Config file not found: $configPath" -ForegroundColor Red
    exit 1
}

$script:lastScriptWriteTime = (Get-Item $scriptPath).LastWriteTime
$script:lastConfigWriteTime = (Get-Item $configPath).LastWriteTime
$script:scriptProcess = $null
$script:isRestarting = $false

Write-Host "🔍 Starting file watcher for:" -ForegroundColor Cyan
Write-Host "   - $TargetScript (modified: $($script:lastScriptWriteTime))" -ForegroundColor Gray
Write-Host "   - $ConfigFile (modified: $($script:lastConfigWriteTime))" -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop watching`n" -ForegroundColor Gray

# Function to restart the script
function Restart-TargetScript {
    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] ✓ File changed - restarting script" -ForegroundColor Green
    
    # Kill previous process if running
    if ($script:scriptProcess -ne $null -and -not $script:scriptProcess.HasExited) {
        try {
            $script:scriptProcess.Kill($true)
            $script:scriptProcess.WaitForExit(2000)
        }
        catch { }
    }
    
    # Start new process
    $scriptDir = Split-Path -Parent $scriptPath
    $script:scriptProcess = Start-Process -FilePath "pwsh" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" `"$scriptDir`"" -PassThru -NoNewWindow
}

# Start the target script initially
Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] ▶️  Starting initial run" -ForegroundColor Cyan
Restart-TargetScript

# Polling loop for file changes
$lastRestartTime = [DateTime]::UtcNow
while ($true) {
    try {
        $currentScriptWriteTime = (Get-Item $scriptPath).LastWriteTime
        $currentConfigWriteTime = (Get-Item $configPath).LastWriteTime
        
        $scriptChanged = $currentScriptWriteTime -ne $script:lastScriptWriteTime
        $configChanged = $currentConfigWriteTime -ne $script:lastConfigWriteTime
        
        if ($scriptChanged -or $configChanged) {
            $timeSinceLastRestart = ([DateTime]::UtcNow - $lastRestartTime).TotalMilliseconds
            
            # Debounce: only restart if 2 seconds have passed since last restart
            if ($timeSinceLastRestart -ge 2000 -and -not $script:isRestarting) {
                $script:isRestarting = $true
                $script:lastScriptWriteTime = $currentScriptWriteTime
                $script:lastConfigWriteTime = $currentConfigWriteTime
                $lastRestartTime = [DateTime]::UtcNow
                
                if ($configChanged) {
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 📝 Config file changed" -ForegroundColor Yellow
                }
                
                Restart-TargetScript
                
                $script:isRestarting = $false
            }
        }
        
        # Check if process has exited
        if ($script:scriptProcess -ne $null -and $script:scriptProcess.HasExited) {
            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] 🛑 Process closed - stopping watcher" -ForegroundColor Yellow
            break
        }
        
        Start-Sleep -Milliseconds 500
    }
    catch {
        Write-Host "⚠ Watcher error: $_" -ForegroundColor Yellow
        Start-Sleep -Milliseconds 500
    }
}

# Cleanup
if ($script:scriptProcess -ne $null -and -not $script:scriptProcess.HasExited) {
    try {
        $script:scriptProcess.Kill($true)
    }
    catch { }
}
Write-Host "`nWatcher stopped" -ForegroundColor Yellow
