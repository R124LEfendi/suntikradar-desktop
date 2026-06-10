@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter tidak ditemukan. Install Flutter stable lalu jalankan lagi script ini.
  exit /b 1
)

if not exist ".env" (
  copy ".env.example" ".env" >nul
)

if not exist "windows" (
  call flutter create --platforms=windows .
  if errorlevel 1 exit /b 1
)

call flutter pub get
if errorlevel 1 exit /b 1

call flutter build windows --release
if errorlevel 1 exit /b 1

echo.
echo Build selesai:
echo %cd%\build\windows\x64\runner\Release
echo.

where iscc >nul 2>nul
if errorlevel 1 (
  echo Inno Setup tidak ditemukan. Folder release sudah siap, tapi installer .exe belum dibuat.
   echo Install Inno Setup lalu jalankan: iscc installer\lahaula_desktop.iss
  exit /b 0
)

iscc installer\lahaula_desktop.iss
if errorlevel 1 exit /b 1

echo Installer selesai:
echo %cd%\dist
