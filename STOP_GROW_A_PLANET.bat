@echo off
setlocal
cd /d "%~dp0"
title Grow a Planet - Stop
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\stop.ps1"
if errorlevel 1 (
    echo.
    echo Stop failed.
    pause
    exit /b 1
)
timeout /t 2 /nobreak >nul
exit /b 0
