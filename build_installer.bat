@echo off
echo Mengaktifkan PowerShell Script Automation...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0build_automation.ps1"
pause
