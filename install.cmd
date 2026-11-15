@echo off
setlocal
set "installer_powershell=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "installer_powershell=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%installer_powershell%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"
set "installer_exit=%errorlevel%"
echo.
pause
exit /b %installer_exit%
