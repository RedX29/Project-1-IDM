<#
.SYNOPSIS
    IDM Activator with Real‑time Status & Prompted Self‑Update.
.DESCRIPTION
    Shows ✅ Working / ⚠️ Untested / ❌ Broken next to each action.
    Checks for script updates and prompts to download them.
    Always interactive – no silent modifications.
.PARAMETER Action
    "Activate", "Freeze", or "Reset". If omitted, GUI is shown.
#>

param(
    [ValidateSet("Activate", "Freeze", "Reset")]
    [string]$Action
)

#region CONFIGURATION
# 🔗 URL to your version.json (must be raw text)
$RemoteMetaUrl = "https://gist.githubusercontent.com/raw/your-gist-id/version.json"

# 🛡️ Local fallback (used if remote is unreachable)
$ScriptTestedUpToVersion = "6.42.33"
#endregion

#region Initialization
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$LogFile = "$env:TEMP\IDM-Activation.log"
$Global:ActionStatus = @{ Activate = "❓ Checking..."; Freeze = "❓ Checking..."; Reset = "✅ Always" }
$Global:RemoteMeta = $null

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$timestamp] $Message" -ErrorAction SilentlyContinue
    if ($Color) { Write-Host $Message -ForegroundColor $Color } else { Write-Host $Message }
}

function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-AsAdmin {
    $scriptPath = $MyInvocation.MyCommand.Path
    $arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""
    if ($Action) { $arguments += " -Action $Action" }
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

# Elevate if needed
if (-not (Test-Admin)) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    Restart-AsAdmin
}

# Get current user SID
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
Write-Log "User SID: $sid" "Gray"

# Detect IDM
$idmPaths = @(
    "${env:ProgramFiles(x86)}\Internet Download Manager\IDMan.exe",
    "${env:ProgramFiles}\Internet Download Manager\IDMan.exe"
)
$idmPath = $idmPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $idmPath) {
    Write-Log "ERROR: IDM not found." "Red"
    Add-Type -AssemblyName System.Windows.Forms
    $msg = "Internet Download Manager is not installed.`nDo you want to download it now?"
    if ([System.Windows.Forms.MessageBox]::Show($msg, "IDM Missing", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question) -eq 'Yes') {
        Start-Process "https://www.internetdownloadmanager.com/download.html"
    }
    exit 1
}
Write-Log "IDM found: $idmPath" "Green"

# Get installed IDM version
function Get-IDMVersion {
    try {
        $versionInfo = (Get-Item -Path $idmPath).VersionInfo
        return "$($versionInfo.FileMajorPart).$($versionInfo.FileMinorPart).$($versionInfo.FileBuildPart)"
    } catch {
        return "0.0.0"
    }
}
$installedVer = Get-IDMVersion
Write-Log "Installed IDM version: $installedVer" "Cyan"

# Determine architecture
$is64 = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment").PROCESSOR_ARCHITECTURE -ne "x86"
$clsidPath = if ($is64) { "HKCU:\Software\Classes\WOW6432Node\CLSID" } else { "HKCU:\Software\Classes\CLSID" }
$clsidPathUser = if ($is64) { "Registry::HKEY_USERS\$sid\Software\Classes\Wow6432Node\CLSID" } else { "Registry::HKEY_USERS\$sid\Software\Classes\CLSID" }
$hkLmPath = if ($is64) { "HKLM:\SOFTWARE\WOW6432Node\Internet Download Manager" } else { "HKLM:\SOFTWARE\Internet Download Manager" }
#endregion

#region Remote Meta & Status Check
function Get-RemoteMeta {
    try {
        $response = Invoke-RestMethod -Uri $RemoteMetaUrl -UseBasicParsing -TimeoutSec 5
        return $response
    } catch {
        Write-Log "Remote meta unreachable. Using local fallback." "Yellow"
        return $null
    }
}

function Update-StatusBadges {
    if ($Global:RemoteMeta -and $Global:RemoteMeta.lastTestedIDM) {
        $testedVer = $Global:RemoteMeta.lastTestedIDM
        $status = $Global:RemoteMeta.status  # "Working", "Broken", etc.

        $installedParts = $installedVer.Split('.') | ForEach-Object { [int]$_ }
        $testedParts = $testedVer.Split('.') | ForEach-Object { [int]$_ }
        $isNewer = $false
        for ($i = 0; $i -lt [Math]::Min($installedParts.Count, $testedParts.Count); $i++) {
            if ($installedParts[$i] -gt $testedParts[$i]) { $isNewer = $true; break }
            if ($installedParts[$i] -lt $testedParts[$i]) { break }
        }
        if (-not $isNewer -and $installedParts.Count -gt $testedParts.Count) { $isNewer = $true }

        if ($status -eq "Broken") {
            $Global:ActionStatus.Activate = "❌ Broken"
            $Global:ActionStatus.Freeze = "❌ Broken"
        } elseif ($isNewer) {
            $Global:ActionStatus.Activate = "⚠️ Untested"
            $Global:ActionStatus.Freeze = "⚠️ Untested"
        } else {
            $Global:ActionStatus.Activate = "✅ Working"
            $Global:ActionStatus.Freeze = "✅ Working"
        }
        $Global:ActionStatus.Reset = "✅ Always"
    } else {
        # Fallback to local hardcoded version
        $installedParts = $installedVer.Split('.') | ForEach-Object { [int]$_ }
        $testedParts = $ScriptTestedUpToVersion.Split('.') | ForEach-Object { [int]$_ }
        $isNewer = $false
        for ($i = 0; $i -lt [Math]::Min($installedParts.Count, $testedParts.Count); $i++) {
            if ($installedParts[$i] -gt $testedParts[$i]) { $isNewer = $true; break }
            if ($installedParts[$i] -lt $testedParts[$i]) { break }
        }
        if (-not $isNewer -and $installedParts.Count -gt $testedParts.Count) { $isNewer = $true }

        if ($isNewer) {
            $Global:ActionStatus.Activate = "⚠️ Untested (offline)"
            $Global:ActionStatus.Freeze = "⚠️ Untested (offline)"
        } else {
            $Global:ActionStatus.Activate = "✅ Working (offline)"
            $Global:ActionStatus.Freeze = "✅ Working (offline)"
        }
        $Global:ActionStatus.Reset = "✅ Always"
    }
}

function Check-ScriptUpdate {
    if ($Global:RemoteMeta -and $Global:RemoteMeta.scriptVersion -and $Global:RemoteMeta.downloadUrl) {
        $currentVersion = "2.1" # Hardcoded script version
        if ($Global:RemoteMeta.scriptVersion -ne $currentVersion) {
            Write-Host "`n🆕 New script version $($Global:RemoteMeta.scriptVersion) available!" -ForegroundColor Cyan
            Write-Host "   Changelog: $($Global:RemoteMeta.changelog)" -ForegroundColor Gray
            $choice = Read-Host "   Download and update now? (y/N)"
            if ($choice -eq 'y' -or $choice -eq 'Y') {
                Write-Host "   Downloading..." -ForegroundColor Yellow
                try {
                    $newScript = Invoke-RestMethod -Uri $Global:RemoteMeta.downloadUrl -UseBasicParsing
                    $currentPath = $MyInvocation.MyCommand.Path
                    $tempPath = "$env:TEMP\IDM-Activator_updated.ps1"
                    $newScript | Out-File -FilePath $tempPath -Encoding UTF8 -Force
                    # Overwrite current
                    Copy-Item -Path $tempPath -Destination $currentPath -Force
                    Write-Host "   ✅ Update applied! Restarting..." -ForegroundColor Green
                    Start-Sleep -Seconds 2
                    # Restart with same params
                    $arguments = "-ExecutionPolicy Bypass -File `"$currentPath`""
                    if ($Action) { $arguments += " -Action $Action" }
                    Start-Process powershell -Verb RunAs -ArgumentList $arguments
                    exit
                } catch {
                    Write-Host "   ❌ Update failed: $_" -ForegroundColor Red
                }
            }
        }
    }
}
#endregion

#region Core Functions
function Backup-RegistryKeys {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
    $backupDir = "$env:SystemRoot\Temp"
    $b1 = "$backupDir\_Backup_HKCU_CLSID_$timestamp.reg"
    $b2 = "$backupDir\_Backup_HKU-${sid}_CLSID_$timestamp.reg"
    Write-Log "Backing up registry..." "Cyan"
    reg export $clsidPath $b1 2>&1 | Out-Null
    reg export $clsidPathUser $b2 2>&1 | Out-Null
    Write-Host "✅ Backups saved to Temp." -ForegroundColor Gray
}

function Add-RegistryFlag {
    Write-Log "Adding activation flag..." "Cyan"
    try {
        New-Item -Path $hkLmPath -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path $hkLmPath -Name "AdvIntDriverEnabled2" -Value 1 -Type DWord -Force
        Write-Host "  ✅ Flag added." -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Failed to add flag." -ForegroundColor Red
    }
}

function Register-FakeDetails {
    Write-Log "Writing fake registration..." "Cyan"
    $fname = Get-Random -Min 1000 -Max 9999
    $lname = Get-Random -Min 1000 -Max 9999
    $email = "$fname.$lname@tonec.com"
    $chars = [char[]]('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')
    $key = -join ((1..25) | ForEach { $chars | Get-Random })
    $key = $key.Substring(0,5) + '-' + $key.Substring(5,5) + '-' + $key.Substring(10,5) + '-' + $key.Substring(15,5) + $key.Substring(20)

    $entries = @(
        @{Path="HKCU:\SOFTWARE\DownloadManager"; Name="FName"; Value=$fname},
        @{Path="HKCU:\SOFTWARE\DownloadManager"; Name="LName"; Value=$lname},
        @{Path="HKCU:\SOFTWARE\DownloadManager"; Name="Email"; Value=$email},
        @{Path="HKCU:\SOFTWARE\DownloadManager"; Name="Serial"; Value=$key},
        @{Path="Registry::HKEY_USERS\$sid\SOFTWARE\DownloadManager"; Name="FName"; Value=$fname},
        @{Path="Registry::HKEY_USERS\$sid\SOFTWARE\DownloadManager"; Name="LName"; Value=$lname},
        @{Path="Registry::HKEY_USERS\$sid\SOFTWARE\DownloadManager"; Name="Email"; Value=$email},
        @{Path="Registry::HKEY_USERS\$sid\SOFTWARE\DownloadManager"; Name="Serial"; Value=$key}
    )
    foreach ($e in $entries) {
        try {
            New-Item -Path $e.Path -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $e.Path -Name $e.Name -Value $e.Value -Force
            Write-Host "  ✅ $($e.Name) = $($e.Value)" -ForegroundColor Green
        } catch {
            Write-Host "  ❌ Failed: $($e.Name)" -ForegroundColor Red
        }
    }
}

function Trigger-IDM-Downloads {
    Write-Log "Triggering IDM (creates CLSID keys)..." "Cyan"
    $tempFile = "$env:SystemRoot\Temp\temp.png"
    $urls = @(
        "https://www.internetdownloadmanager.com/images/idm_box_min.png",
        "https://www.internetdownloadmanager.com/register/IDMlib/images/idman_logos.png",
        "https://www.internetdownloadmanager.com/pictures/idm_about.png"
    )
    foreach ($url in $urls) {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        Start-Process -FilePath $idmPath -ArgumentList "/n /d $url /p $env:SystemRoot\Temp /f temp.png" -WindowStyle Hidden -Wait
        Start-Sleep -Seconds 2
    }
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    Write-Host "  ✅ Triggers done." -ForegroundColor Green
}

function Get-TargetCLSIDs {
    $found = @()
    $regPaths = @($clsidPath, $clsidPathUser)
    foreach ($regPath in $regPaths) {
        $subKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\{[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}\}$' }
        foreach ($key in $subKeys) {
            $fullPath = $key.PSPath
            $def = (Get-ItemProperty -Path $fullPath -ErrorAction SilentlyContinue).'(default)'
            $ver = (Get-ItemProperty -Path "$fullPath\Version" -ErrorAction SilentlyContinue).'(default)'
            $props = Get-ItemProperty -Path $fullPath -ErrorAction SilentlyContinue
            $match = $false
            if ($def -match "^\d+$" -and $key.SubKeyCount -eq 0) { $match = $true }
            if ($def -match "\+|=" -and $key.SubKeyCount -eq 0) { $match = $true }
            if ($ver -match "^\d+$" -and $key.SubKeyCount -eq 1) { $match = $true }
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -match "MData|Model|scansk|Therad") { $match = $true }
            }
            if ($match) { $found += $fullPath }
        }
    }
    return $found
}

function Invoke-LockKeys {
    $keys = Get-TargetCLSIDs
    if ($keys.Count -eq 0) { Write-Host "  ⚠️ No CLSID keys found to lock." -ForegroundColor Yellow; return }
    Write-Host "  🔒 Locking $($keys.Count) key(s)..." -ForegroundColor Cyan
    foreach ($k in $keys) {
        if (Test-Path $k) {
            Start-Process -FilePath "icacls.exe" -ArgumentList "`"$k`" /deny Everyone:F" -Wait -WindowStyle Hidden
            Write-Host "    ✅ Locked: $k" -ForegroundColor Green
        }
    }
}

function Invoke-UnlockAndDeleteKeys {
    $keys = Get-TargetCLSIDs
    if ($keys.Count -eq 0) { Write-Host "  ⚠️ No CLSID keys found to delete." -ForegroundColor Yellow; return }
    Write-Host "  🗑️ Unlocking and deleting $($keys.Count) key(s)..." -ForegroundColor Cyan
    foreach ($k in $keys) {
        if (Test-Path $k) {
            Start-Process -FilePath "takeown.exe" -ArgumentList "/f `"$k`"" -Wait -WindowStyle Hidden
            Start-Process -FilePath "icacls.exe" -ArgumentList "`"$k`" /grant Administrators:F" -Wait -WindowStyle Hidden
            Remove-Item -Path $k -Force -Recurse -ErrorAction SilentlyContinue
            Write-Host "    ✅ Deleted: $k" -ForegroundColor Green
        }
    }
    $delPaths = @("HKCU:\Software\DownloadManager", "Registry::HKEY_USERS\$sid\Software\DownloadManager")
    foreach ($p in $delPaths) { Remove-Item -Path $p -Force -Recurse -ErrorAction SilentlyContinue }
}
#endregion

#region Actions (with Safety wrapper)
function Invoke-SafeAction {
    param([string]$ActionName, [scriptblock]$ActionBlock)

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  ACTION: $ActionName" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan

    # Check status warning
    if ($ActionName -match "Activate|Freeze") {
        $status = $Global:ActionStatus[$ActionName.Replace(" IDM","").Replace(" Trial","")]
        if ($status -match "❌|⚠️") {
            Write-Host "⚠️  WARNING: This action is currently marked as $status" -ForegroundColor Red
            $proceed = Read-Host "Type 'YES' to attempt anyway, or anything else to cancel"
            if ($proceed -ne "YES") { Write-Host "Cancelled." -ForegroundColor Red; return }
        }
    }

    $confirm = Read-Host "Type 'YES' to proceed with $ActionName, or anything else to cancel"
    if ($confirm -ne "YES") { Write-Host "❌ Cancelled." -ForegroundColor Red; return }

    try {
        & $ActionBlock
        Write-Host "`n✅ $ActionName completed!" -ForegroundColor Green
        [System.Windows.Forms.MessageBox]::Show("$ActionName completed successfully!", "Success", "OK", "Information")
    } catch {
        Write-Host "`n❌ Error: $_" -ForegroundColor Red
        [System.Windows.Forms.MessageBox]::Show("Error: $_", "Error", "OK", "Error")
    }
}

function Do-Activate {
    Invoke-SafeAction -ActionName "Activate IDM" -ActionBlock {
        Backup-RegistryKeys
        $delPaths = @("HKCU:\Software\DownloadManager", "Registry::HKEY_USERS\$sid\Software\DownloadManager")
        foreach ($p in $delPaths) { Remove-Item -Path $p -Force -Recurse -ErrorAction SilentlyContinue }
        Add-RegistryFlag
        Register-FakeDetails
        Trigger-IDM-Downloads
        Invoke-LockKeys
    }
}

function Do-Freeze {
    Invoke-SafeAction -ActionName "Freeze Trial" -ActionBlock {
        Backup-RegistryKeys
        $delPaths = @("HKCU:\Software\DownloadManager", "Registry::HKEY_USERS\$sid\Software\DownloadManager")
        foreach ($p in $delPaths) { Remove-Item -Path $p -Force -Recurse -ErrorAction SilentlyContinue }
        Add-RegistryFlag
        Trigger-IDM-Downloads
        Invoke-LockKeys
    }
}

function Do-Reset {
    Invoke-SafeAction -ActionName "Reset Trial" -ActionBlock {
        Backup-RegistryKeys
        Invoke-UnlockAndDeleteKeys
    }
}
#endregion

#region Fetch Status & Check Update (run once at start)
$Global:RemoteMeta = Get-RemoteMeta
Update-StatusBadges
Check-ScriptUpdate
#endregion

#region GUI (if no -Action parameter)
if (-not $Action) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "IDM Activator (Self-Aware)"
    $form.Size = New-Object System.Drawing.Size(380, 340)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Internet Download Manager"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Size = New-Object System.Drawing.Size(340, 30)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblTitle.TextAlign = "MiddleCenter"
    $form.Controls.Add($lblTitle)

    $lblVersion = New-Object System.Windows.Forms.Label
    $lblVersion.Text = "IDM v$installedVer  |  Status: Online"
    $lblVersion.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
    $lblVersion.Size = New-Object System.Drawing.Size(340, 20)
    $lblVersion.Location = New-Object System.Drawing.Point(20, 45)
    $lblVersion.TextAlign = "MiddleCenter"
    $lblVersion.ForeColor = [System.Drawing.Color]::Gray
    $form.Controls.Add($lblVersion)

    $btnActivate = New-Object System.Windows.Forms.Button
    $btnActivate.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnActivate.Size = New-Object System.Drawing.Size(320, 40)
    $btnActivate.Location = New-Object System.Drawing.Point(20, 90)
    $btnActivate.BackColor = [System.Drawing.Color]::FromArgb(200, 230, 200)
    $btnActivate.Add_Click({ 
        $btnActivate.Enabled = $false; $btnFreeze.Enabled = $false; $btnReset.Enabled = $false
        Do-Activate
        $btnActivate.Enabled = $true; $btnFreeze.Enabled = $true; $btnReset.Enabled = $true
    })
    $form.Controls.Add($btnActivate)

    $btnFreeze = New-Object System.Windows.Forms.Button
    $btnFreeze.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnFreeze.Size = New-Object System.Drawing.Size(320, 40)
    $btnFreeze.Location = New-Object System.Drawing.Point(20, 140)
    $btnFreeze.BackColor = [System.Drawing.Color]::FromArgb(255, 230, 180)
    $btnFreeze.Add_Click({ 
        $btnActivate.Enabled = $false; $btnFreeze.Enabled = $false; $btnReset.Enabled = $false
        Do-Freeze
        $btnActivate.Enabled = $true; $btnFreeze.Enabled = $true; $btnReset.Enabled = $true
    })
    $form.Controls.Add($btnFreeze)

    $btnReset = New-Object System.Windows.Forms.Button
    $btnReset.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnReset.Size = New-Object System.Drawing.Size(320, 40)
    $btnReset.Location = New-Object System.Drawing.Point(20, 190)
    $btnReset.BackColor = [System.Drawing.Color]::FromArgb(255, 200, 200)
    $btnReset.Add_Click({ 
        $btnActivate.Enabled = $false; $btnFreeze.Enabled = $false; $btnReset.Enabled = $false
        Do-Reset
        $btnActivate.Enabled = $true; $btnFreeze.Enabled = $true; $btnReset.Enabled = $true
    })
    $form.Controls.Add($btnReset)

    $btnExit = New-Object System.Windows.Forms.Button
    $btnExit.Text = "✖ Exit"
    $btnExit.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $btnExit.Size = New-Object System.Drawing.Size(80, 30)
    $btnExit.Location = New-Object System.Drawing.Point(140, 250)
    $btnExit.Add_Click({ $form.Close() })
    $form.Controls.Add($btnExit)

    # Update button texts with status
    function Update-ButtonStatus {
        $btnActivate.Text = "✅ Activate IDM  [$($Global:ActionStatus.Activate)]"
        $btnFreeze.Text = "⏸️ Freeze Trial  [$($Global:ActionStatus.Freeze)]"
        $btnReset.Text = "🔄 Reset Trial  [$($Global:ActionStatus.Reset)]"

        # Color code the status
        if ($Global:ActionStatus.Activate -match "✅") { $btnActivate.BackColor = [System.Drawing.Color]::FromArgb(200, 240, 200) }
        elseif ($Global:ActionStatus.Activate -match "⚠️") { $btnActivate.BackColor = [System.Drawing.Color]::FromArgb(255, 240, 180) }
        elseif ($Global:ActionStatus.Activate -match "❌") { $btnActivate.BackColor = [System.Drawing.Color]::FromArgb(255, 200, 200) }
        # same for freeze
        if ($Global:ActionStatus.Freeze -match "✅") { $btnFreeze.BackColor = [System.Drawing.Color]::FromArgb(200, 240, 200) }
        elseif ($Global:ActionStatus.Freeze -match "⚠️") { $btnFreeze.BackColor = [System.Drawing.Color]::FromArgb(255, 240, 180) }
        elseif ($Global:ActionStatus.Freeze -match "❌") { $btnFreeze.BackColor = [System.Drawing.Color]::FromArgb(255, 200, 200) }
    }
    Update-ButtonStatus

    $form.ShowDialog() | Out-Null
    exit
}
#endregion

#region CLI Menu (with statuses)
function Show-CLIMenu {
    Clear-Host
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "       IDM Activator (Self-Aware v2.1)" -ForegroundColor White
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "  IDM Version: $installedVer" -ForegroundColor Gray
    $remoteStatus = if ($Global:RemoteMeta) { "Online" } else { "Offline (fallback)" }
    Write-Host "  Status Check: $remoteStatus" -ForegroundColor Gray
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  [1] Activate IDM      $($Global:ActionStatus.Activate)" -ForegroundColor Green
    Write-Host "  [2] Freeze Trial      $($Global:ActionStatus.Freeze)" -ForegroundColor Yellow
    Write-Host "  [3] Reset Trial       $($Global:ActionStatus.Reset)" -ForegroundColor Red
    Write-Host "  [4] Download IDM (Official)" -ForegroundColor Blue
    Write-Host "  [0] Exit" -ForegroundColor Gray
    Write-Host "==================================================" -ForegroundColor Cyan
    return Read-Host "Enter option"
}

# If CLI is invoked with -Action, we bypass the menu and go straight to the action (still interactive)
if ($Action) {
    switch ($Action) {
        "Activate" { Do-Activate }
        "Freeze"   { Do-Freeze }
        "Reset"    { Do-Reset }
    }
    exit
}

# Otherwise, show interactive CLI menu
do {
    $choice = Show-CLIMenu
    switch ($choice) {
        "1" { Do-Activate }
        "2" { Do-Freeze }
        "3" { Do-Reset }
        "4" { Start-Process "https://www.internetdownloadmanager.com/download.html" }
        "0" { Write-Host "Exiting..." -ForegroundColor Gray; break }
        default { Write-Host "Invalid option." -ForegroundColor Red }
    }
    if ($choice -ne "0" -and $choice -in @("1","2","3","4")) {
        Read-Host "`nPress Enter to continue..."
    }
} while ($choice -ne "0")
#endregion