@echo off
setlocal ENABLEDELAYEDEXPANSION

cd /d "%~dp0\..\.."
set ROOT=%CD%

echo ============================================
echo RP Local Server - Requirements Check
echo Root: %ROOT%
echo ============================================

set FAIL=0

if not exist "%ROOT%\server\artifacts\FXServer.exe" (
  echo [FEHLER] FXServer.exe fehlt: server\artifacts\FXServer.exe
  set FAIL=1
) else (
  echo [OK] FXServer.exe gefunden.
)

if not exist "%ROOT%\server\config\server.cfg" (
  echo [FEHLER] server.cfg fehlt: server\config\server.cfg
  set FAIL=1
) else (
  echo [OK] server.cfg gefunden.
)

if not exist "%ROOT%\server\sql\rp_database.sql" (
  echo [FEHLER] SQL-Datei fehlt: server\sql\rp_database.sql
  set FAIL=1
) else (
  echo [OK] SQL-Datei gefunden.
)

if not exist "%ROOT%\server\sql\rp_admin.sql" (
  echo [FEHLER] SQL-Datei fehlt: server\sql\rp_admin.sql
  set FAIL=1
) else (
  echo [OK] SQL-Datei rp_admin.sql gefunden.
)

if not exist "%ROOT%\server\resources\[core]\rp_core\fxmanifest.lua" (
  echo [FEHLER] Core Resource fehlt: rp_core
  set FAIL=1
) else (
  echo [OK] Core Resource rp_core gefunden.
)

if not exist "%ROOT%\server\resources\[core]\rp_admin\fxmanifest.lua" (
  echo [FEHLER] Core Resource fehlt: rp_admin
  set FAIL=1
) else (
  echo [OK] Core Resource rp_admin gefunden.
)

if not exist "%ROOT%\server\resources\[dependencies]\oxmysql\lib\MySQL.lua" (
  echo [FEHLER] oxmysql ist unvollstaendig: lib\MySQL.lua fehlt.
  set FAIL=1
) else (
  echo [OK] oxmysql lib\MySQL.lua gefunden.
)

if not exist "%ROOT%\server\resources\[dependencies]\async\fxmanifest.lua" (
  echo [FEHLER] async fehlt: server\resources\[dependencies]\async\fxmanifest.lua
  set FAIL=1
) else (
  echo [OK] async fxmanifest.lua gefunden.
)

if not exist "%ROOT%\server\resources\[dependencies]\es_extended\fxmanifest.lua" (
  echo [FEHLER] es_extended ist unvollstaendig: fxmanifest.lua fehlt.
  set FAIL=1
) else (
  echo [OK] es_extended fxmanifest.lua gefunden.
)

echo.
if "%FAIL%"=="1" (
  echo Ergebnis: FEHLER gefunden. Bitte Hinweise oben beheben.
  exit /b 1
) else (
  echo Ergebnis: Alle Pflichtchecks erfolgreich.
  exit /b 0
)
