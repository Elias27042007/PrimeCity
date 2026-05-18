@echo off
setlocal

cd /d "%~dp0\..\.."
set ROOT=%CD%

call "%ROOT%\server\tools\check_requirements.bat"
if errorlevel 1 (
  echo.
  echo Start abgebrochen wegen fehlender Voraussetzungen.
  pause
  exit /b 1
)

echo.
echo Starte FXServer mit server\config\server.cfg ...
cd /d "%ROOT%\server"

echo Beende ggf. laufenden FXServer ...
taskkill /F /IM FXServer.exe >nul 2>&1

if exist "%ROOT%\server\txData" (
  if not exist "%ROOT%\server\txData_backup" (
    echo txData gefunden - sichere als txData_backup ...
    ren "%ROOT%\server\txData" "txData_backup"
  ) else (
    echo txData gefunden, aber txData_backup existiert bereits - ueberspringe Umbenennen.
  )
)

"%ROOT%\server\artifacts\FXServer.exe" +set citizen_dir "%ROOT%\server\artifacts\citizen\" +exec config\server.cfg

endlocal
