@echo off
setlocal
cd /d "%~dp0"
title Grow a Planet - Development
echo.
echo ===========================
echo    GROW A PLANET START
echo ===========================
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\start-dev.ps1"
if errorlevel 1 (
    echo.
    echo Startup failed. Check the error above or logs\rojo.error.log.
    pause
    exit /b 1
)
echo.
echo Rojo and background Git sync ready.
timeout /t 2 /nobreak >nul
exit /b 0
