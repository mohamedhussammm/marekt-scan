@echo off
title Market Scan Backend
echo ============================================
echo   Market Scan - Starting Backend + Tunnel
echo ============================================
echo.

set NGROK="C:\Users\Legion\AppData\Local\Microsoft\WinGet\Packages\Ngrok.Ngrok_Microsoft.Winget.Source_8wekyb3d8bbwe\ngrok.exe"

:: Start Node.js backend in a new window
start "Market Scan API" cmd /k "cd /d "e:\Market Scan\backend" && node server.js"

:: Wait 2 seconds for backend to boot
timeout /t 2 /nobreak > nul

:: Start ngrok with your permanent static domain
echo Starting ngrok tunnel on your permanent domain...
echo.
echo Your API is now live at:
echo   https://anytime-font-drainable.ngrok-free.dev/api
echo.
echo This URL NEVER changes - it works from any network!
echo.
start "ngrok Tunnel" %NGROK% http --domain=anytime-font-drainable.ngrok-free.dev 3000

echo App Settings ^> API Server Address:
echo   https://anytime-font-drainable.ngrok-free.dev/api
echo.
pause
