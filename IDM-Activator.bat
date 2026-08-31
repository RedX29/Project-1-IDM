@echo off
setlocal enabledelayedexpansion
title IDM Activator
color 0A

:: ------------------------------------------------------------
::  SCRIPT VERSION
:: ------------------------------------------------------------
set "SCRIPT_VERSION=1.0"

:: ------------------------------------------------------------
::  ADMIN CHECK
:: ------------------------------------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process cmd -Verb RunAs -ArgumentList '/c \"%~f0\"'"
    exit
)

:: ------------------------------------------------------------
::  FIND IDM
:: ------------------------------------------------------------
set "IDM_PATH="
if exist "%ProgramFiles(x86)%\Internet Download Manager\IDMan.exe" set "IDM_PATH=%ProgramFiles(x86)%\Internet Download Manager\IDMan.exe"
if exist "%ProgramFiles%\Internet Download Manager\IDMan.exe" set "IDM_PATH=%ProgramFiles%\Internet Download Manager\IDMan.exe"
if not defined IDM_PATH (
    echo IDM is not installed.
    echo Please download from: https://www.internetdownloadmanager.com/download.html
    pause
    exit
)

:: ------------------------------------------------------------
::  GET IDM VERSION
:: ------------------------------------------------------------
set "IDM_VER="
for /f "tokens=2 delims==" %%i in ('wmic datafile where name^="%IDM_PATH:\=\\%" get version /value ^| find "="') do set "IDM_VER=%%i"
if not defined IDM_VER (
    for /f "delims=" %%i in ('powershell -Command "(Get-Item '%IDM_PATH%').VersionInfo.FileVersion"') do set "IDM_VER=%%i"
)
set "IDM_VER=%IDM_VER: =%"
set "IDM_VER=%IDM_VER:,=.%"

:: ------------------------------------------------------------
::  STATUS (plain text, no emojis)
:: ------------------------------------------------------------
set "STATUS=Working"

:: ------------------------------------------------------------
::  REGISTRY PATHS
:: ------------------------------------------------------------
set "HKLM_KEY=HKLM\SOFTWARE\Internet Download Manager"
if not "%PROCESSOR_ARCHITECTURE%"=="x86" set "HKLM_KEY=HKLM\SOFTWARE\WOW6432Node\Internet Download Manager"

:: ------------------------------------------------------------
::  MENU LOOP
:: ------------------------------------------------------------
:menu
cls
echo ==================================================
echo        IDM Activator v%SCRIPT_VERSION%
echo ==================================================
echo   Installed IDM : %IDM_VER%
echo   Status        : %STATUS%
echo ==================================================
echo   [1] Activate IDM
echo   [2] Freeze Trial (30-day freeze)
echo   [3] Reset Activation / Trial
echo   [4] Download IDM (Official)
echo   [5] Check for Updates
echo   [0] Exit
echo ==================================================
set /p choice="Enter option: "

if "%choice%"=="1" goto activate
if "%choice%"=="2" goto freeze
if "%choice%"=="3" goto reset
if "%choice%"=="4" goto download
if "%choice%"=="5" goto update_check
if "%choice%"=="0" exit
echo Invalid option.
pause >nul
goto menu

:: ------------------------------------------------------------
::  UPDATE CHECK – with file existence check + download
:: ------------------------------------------------------------
:update_check
cls
echo ==================================================
echo        Running Update Checker...
echo ==================================================
set "PS_FILE=%~dp0Update-Check.ps1"
if not exist "%PS_FILE%" (
    echo Update-Check.ps1 is missing.
    echo This file is needed to check for updates.
    echo Do you want to download it from GitHub? (y/N)
    set /p DOWNLOAD="> "
    if /i "!DOWNLOAD!"=="y" (
        echo Downloading Update-Check.ps1 from GitHub...
        bitsadmin /transfer "GetUpdateChecker" /download /priority normal "https://raw.githubusercontent.com/RedX29/Project-1-IDM/main/Update-Check.ps1" "%PS_FILE%" >nul 2>&1
        if exist "%PS_FILE%" (
            echo Download successful.
        ) else (
            echo Download failed. Please download manually from:
            echo https://raw.githubusercontent.com/RedX29/Project-1-IDM/main/Update-Check.ps1
            echo Place it in the same folder as this batch file.
            pause
            goto menu
        )
    ) else (
        echo Update checker skipped. Returning to menu.
        pause
        goto menu
    )
)
echo Press any key to run the update checker...
pause >nul
powershell -ExecutionPolicy Bypass -File "%PS_FILE%"
goto menu

:: ------------------------------------------------------------
::  ACTIONS (stable)
:: ------------------------------------------------------------
:activate
call :confirm "Activate IDM"
if errorlevel 1 goto menu
call :backup
reg delete "HKCU\Software\DownloadManager" /f >nul 2>&1
reg add "%HKLM_KEY%" /v AdvIntDriverEnabled2 /t REG_DWORD /d 1 /f >nul 2>&1
call :generate_serial
call :trigger_idm
call :lock_keys
echo Activation complete!
pause
goto menu

:freeze
call :confirm "Freeze Trial"
if errorlevel 1 goto menu
call :backup
reg delete "HKCU\Software\DownloadManager" /f >nul 2>&1
reg add "%HKLM_KEY%" /v AdvIntDriverEnabled2 /t REG_DWORD /d 1 /f >nul 2>&1
call :trigger_idm
call :lock_keys
echo Trial frozen!
pause
goto menu

:reset
call :confirm "Reset Trial"
if errorlevel 1 goto menu
call :backup
call :unlock_and_delete_keys
echo Reset complete!
pause
goto menu

:download
start https://www.internetdownloadmanager.com/download.html
goto menu

:confirm
set /p confirm=Type YES to proceed with %~1, or anything else to cancel: 
if /i not "%confirm%"=="YES" (
    echo Cancelled.
    exit /b 1
)
exit /b 0

:backup
set "timestamp=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "timestamp=%timestamp: =0%"
reg export "HKCU\Software\Classes\CLSID" "%TEMP%\_Backup_CLSID_%timestamp%.reg" >nul 2>&1
echo Backup saved to %TEMP%\_Backup_CLSID_%timestamp%.reg
exit /b

:generate_serial
set /a fname=%random% %% 9000 + 1000
set /a lname=%random% %% 9000 + 1000
set "email=%fname%.%lname%@tonec.com"
set "chars=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
set "serial="
for /l %%i in (1,1,25) do (
    set /a r=!random! %% 36
    call set "serial=!serial!!chars:~!r!,1!"
)
set "serial=!serial:~0,5!-!serial:~5,5!-!serial:~10,5!-!serial:~15,5!!serial:~20!"
reg add "HKCU\Software\DownloadManager" /v FName /t REG_SZ /d %fname% /f >nul 2>&1
reg add "HKCU\Software\DownloadManager" /v LName /t REG_SZ /d %lname% /f >nul 2>&1
reg add "HKCU\Software\DownloadManager" /v Email /t REG_SZ /d %email% /f >nul 2>&1
reg add "HKCU\Software\DownloadManager" /v Serial /t REG_SZ /d %serial% /f >nul 2>&1
echo   Serial: %serial%
exit /b

:trigger_idm
set "urls[0]=https://www.internetdownloadmanager.com/images/idm_box_min.png"
set "urls[1]=https://www.internetdownloadmanager.com/register/IDMlib/images/idman_logos.png"
set "urls[2]=https://www.internetdownloadmanager.com/pictures/idm_about.png"
for /l %%i in (0,1,2) do (
    start /min "" "%IDM_PATH%" /n /d !urls[%%i]! /p "%TEMP%" /f temp_%%i.png
    ping 127.0.0.1 -n 3 >nul
)
del "%TEMP%\temp_*.png" >nul 2>&1
exit /b

:lock_keys
echo Scanning for IDM-related CLSID keys...
for /f "delims=" %%a in ('reg query "HKCU\Software\Classes\CLSID" /k /f { /s 2^>nul ^| find "{"') do (
    call :check_and_lock "%%a"
)
exit /b

:check_and_lock
set "key=%~1"
set "match="
for /f "tokens=2*" %%b in ('reg query "%key%" /ve 2^>nul') do (
    if "%%c" neq "" (
        echo %%c | findstr /r "^[0-9][0-9]*$" >nul && set "match=1"
        echo %%c | findstr /r "[+=]" >nul && set "match=1"
    )
)
reg query "%key%\Version" >nul 2>&1 && set "match=1"
for /f "skip=2 tokens=3" %%v in ('reg query "%key%" /v MData 2^>nul') do set "match=1"
for /f "skip=2 tokens=3" %%v in ('reg query "%key%" /v Model 2^>nul') do set "match=1"
for /f "skip=2 tokens=3" %%v in ('reg query "%key%" /v scansk 2^>nul') do set "match=1"
for /f "skip=2 tokens=3" %%v in ('reg query "%key%" /v Therad 2^>nul') do set "match=1"
if defined match (
    echo Locking: %key%
    icacls "%key%" /deny Everyone:F >nul 2>&1
)
exit /b

:unlock_and_delete_keys
echo Unlocking and deleting CLSID keys...
for /f "delims=" %%a in ('reg query "HKCU\Software\Classes\CLSID" /k /f { /s 2^>nul ^| find "{"') do (
    call :unlock_and_delete "%%a"
)
reg delete "HKCU\Software\DownloadManager" /f >nul 2>&1
exit /b

:unlock_and_delete
set "key=%~1"
icacls "%key%" /grant Administrators:F >nul 2>&1
takeown /f "%key%" >nul 2>&1
reg delete "%key%" /f >nul 2>&1
echo Deleted: %key%
exit /b