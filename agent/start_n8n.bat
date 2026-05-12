@echo off
echo Starting n8n Credit Assessment Agent...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0start_n8n.ps1"
pause
