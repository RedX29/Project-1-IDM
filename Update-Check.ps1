# Update-Check.ps1
# Separate PowerShell script to check for IDM compatibility and script updates.
# No emojis, plain text output.

$ErrorActionPreference = "Stop"

# GitHub URLs (change these if your repo changes)
$SCRIPT_URL = "https://raw.githubusercontent.com/RedX29/Project-1-IDM/main/IDM-Activator.bat"
$VERSION_URL = "https://raw.githubusercontent.com/RedX29/Project-1-IDM/main/version.txt"
$SCRIPT_VER_URL = "https://raw.githubusercontent.com/RedX29/Project-1-IDM/main/script_version.txt"

Write-Host "----------------------------------------------" -ForegroundColor Cyan
Write-Host "  Update Checker v1.0" -ForegroundColor White
Write-Host "----------------------------------------------" -ForegroundColor Cyan

# Get installed IDM version (from registry or file)
$idmPaths = @(
    "${env:ProgramFiles(x86)}\Internet Download Manager\IDMan.exe",
    "${env:ProgramFiles}\Internet Download Manager\IDMan.exe"
)
$idmPath = $idmPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $idmPath) {
    Write-Host "IDM not found." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}
$idmVer = (Get-Item $idmPath).VersionInfo.FileVersion
$idmVer = $idmVer -replace ',', '.'
Write-Host "Installed IDM version: $idmVer" -ForegroundColor Gray

# Download remote files
try {
    $testedVer = (Invoke-WebRequest -Uri $VERSION_URL -UseBasicParsing).Content.Trim()
    $remoteScriptVer = (Invoke-WebRequest -Uri $SCRIPT_VER_URL -UseBasicParsing).Content.Trim()
} catch {
    Write-Host "Failed to reach GitHub. Check your internet connection." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

# Compare IDM versions
Write-Host "Remote tested version: $testedVer" -ForegroundColor Gray
$local = [Version]$idmVer
$remote = [Version]$testedVer
if ($local -gt $remote) {
    Write-Host "Status: Your IDM is newer than the tested version (Untested)." -ForegroundColor Yellow
} else {
    Write-Host "Status: Working (compatible)." -ForegroundColor Green
}

# Compare script versions
Write-Host "Remote script version: $remoteScriptVer" -ForegroundColor Gray
$localScriptVer = "1.0"  # This must match the batch's SCRIPT_VERSION
if ($remoteScriptVer -ne $localScriptVer) {
    Write-Host "New script version available ($remoteScriptVer)." -ForegroundColor Cyan
    $update = Read-Host "Download and update now? (y/N)"
    if ($update -eq 'y' -or $update -eq 'Y') {
        Write-Host "Downloading new batch file..." -ForegroundColor Yellow
        try {
            $newBat = Invoke-WebRequest -Uri $SCRIPT_URL -UseBasicParsing
            $newBat.Content | Out-File -FilePath "$env:TEMP\IDM-Activator_new.bat" -Encoding ASCII -Force
            $currentBat = Join-Path $PSScriptRoot "IDM-Activator.bat"
            if (Test-Path $currentBat) {
                Copy-Item -Path "$env:TEMP\IDM-Activator_new.bat" -Destination $currentBat -Force
                Write-Host "Update successful. Restarting the batch file..." -ForegroundColor Green
                Start-Process $currentBat
                exit
            } else {
                Write-Host "Batch file not found in the current folder. Please copy the new version manually." -ForegroundColor Red
            }
        } catch {
            Write-Host "Update failed: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Update cancelled." -ForegroundColor Gray
    }
} else {
    Write-Host "You have the latest script version." -ForegroundColor Green
}

Write-Host "----------------------------------------------" -ForegroundColor Cyan
Read-Host "Press Enter to exit"