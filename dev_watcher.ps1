param(
    [string]$ScriptPath = "C:\Users\visha\OneDrive\Desktop\New folder\music_app.py",
    [int]$DebounceMs = 500
)

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = Split-Path $ScriptPath -Parent
$watcher.Filter = Split-Path $ScriptPath -Leaf
$watcher.EnableRaisingEvents = $true
$watcher.NotifyFilter = [IO.NotifyFilters]::LastWrite

$global:process = $null
$global:timer = $null

function Start-App {
    if ($global:process -and !$global:process.HasExited) {
        $global:process.Kill()
        $global:process.Dispose()
        Start-Sleep -Milliseconds 200
    }
    Write-Host "[dev] Starting app..." -ForegroundColor Cyan
    $global:process = [System.Diagnostics.Process]::Start("python", "`"$ScriptPath`"")
}

function Stop-App {
    if ($global:process -and !$global:process.HasExited) {
        $global:process.Kill()
        $global:process.Dispose()
    }
}

$action = {
    if ($global:timer) {
        $global:timer.Dispose()
        $global:timer = $null
    }
    $global:timer = [System.Timers.Timer]::new($DebounceMs)
    $global:timer.AutoReset = $false
    Register-ObjectEvent -InputObject $global:timer -EventName Elapsed -Action {
        Write-Host "[dev] File changed, restarting..." -ForegroundColor Yellow
        Start-App
        $global:timer.Dispose()
        $global:timer = $null
    } | Out-Null
    $global:timer.Start()
}

Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action | Out-Null

Write-Host "Watching $ScriptPath for changes..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray

Start-App

try {
    while ($true) { Start-Sleep -Seconds 1 }
} finally {
    Stop-App
    $watcher.Dispose()
}
