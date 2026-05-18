@echo off
setlocal

cd /d "%~dp0\..\.."
set ROOT=%CD%

call "%ROOT%\server\tools\check_requirements.bat"
if errorlevel 1 (
  echo.
  echo Debug-Start abgebrochen wegen fehlender Voraussetzungen.
  pause
  exit /b 1
)

echo.
echo Starte FXServer im Debug-Modus ...
cd /d "%ROOT%\server"
"%ROOT%\server\artifacts\FXServer.exe" +set citizen_dir "%ROOT%\server\artifacts\citizen\" +setr rp_debugMode true +exec config\server.cfg

endlocal
