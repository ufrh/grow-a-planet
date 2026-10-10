@echo off
setlocal
cd /d "%~dp0"
title Grow a Planet - Push
set /p "MSG=Commit message (blank for default): "
if not defined MSG set "MSG=Update Grow a Planet"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\push.ps1" "%MSG%"
if errorlevel 1 (
    echo.
    echo Push failed. Local changes are safe.
    pause
    exit /b 1
)
echo.
pause
exit /b 0
