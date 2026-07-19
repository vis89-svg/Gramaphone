param(
    [string]$ScriptPath = "C:\Users\visha\OneDrive\Desktop\New folder\music_app.py",
    [string]$OutputDir = "C:\Users\visha\OneDrive\Desktop\New folder\dist"
)

# Build standalone .exe with PyInstaller
Write-Host "Building desktop app..." -ForegroundColor Cyan

# Ensure PyInstaller is installed
$py = (Get-Command python).Source
& $py -m pip install pyinstaller --quiet

# Build single-file executable
& $py -m PyInstaller `
    --onefile `
    --windowed `
    --name "tmp3" `
    --icon "$PSScriptRoot\icon.ico" `
    --add-data "$PSScriptRoot\yt_dlp;yt_dlp" `
    --hidden-import "PIL._tkinter_finder" `
    --hidden-import "vlc" `
    --hidden-import "requests" `
    --distpath "$OutputDir" `
    "$ScriptPath"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nBuild complete! EXE at: $OutputDir\tmp3.exe" -ForegroundColor Green
    Write-Host "You can now run tmp3.exe directly (no Python required)." -ForegroundColor DarkGray
} else {
    Write-Host "Build failed." -ForegroundColor Red
}
