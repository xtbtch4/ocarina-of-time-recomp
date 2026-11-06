@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Ocarina of Time Recomp - Local NUP Builder
cd /d "%~dp0"

echo.
echo ================================================
echo   Ocarina of Time Recomp - local NUP build
echo ================================================
echo Your .nup file stays on this PC. It is never uploaded.
echo.

where py >nul 2>nul
if errorlevel 1 (
  echo ERROR: Python Launcher not found. Install Python 3.14 x64 from python.org.
  pause
  exit /b 1
)
py -3.14 -c "import compression.zstd, numpy, capstone" >nul 2>nul
if errorlevel 1 (
  echo Installing Python dependencies...
  py -3.14 -m pip install --upgrade pip
  py -3.14 -m pip install numpy==2.5.4 capstone==5.0.9
  if errorlevel 1 goto :error
)
py -3.14 -c "import compression.zstd" >nul 2>nul
if errorlevel 1 (
  echo ERROR: Python 3.14 or newer is required for the built-in zstd module.
  pause
  exit /b 1
)

if not exist "C:\msys64\ucrt64\bin\clang.exe" (
  echo ERROR: MSYS2 UCRT64 Clang is missing.
  echo Install MSYS2 to C:\msys64, then in the MSYS2 UCRT64 terminal run:
  echo pacman -Syu
  echo pacman -S --needed mingw-w64-ucrt-x86_64-toolchain mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-clang mingw-w64-ucrt-x86_64-lld mingw-w64-ucrt-x86_64-ninja mingw-w64-ucrt-x86_64-SDL3 mingw-w64-ucrt-x86_64-vulkan-headers mingw-w64-ucrt-x86_64-vulkan-loader mingw-w64-ucrt-x86_64-opus mingw-w64-ucrt-x86_64-libvpx mingw-w64-ucrt-x86_64-dav1d mingw-w64-ucrt-x86_64-vulkan-memory-allocator
  pause
  exit /b 1
)
if not exist "C:\msys64\ucrt64\bin\ninja.exe" (
  echo ERROR: Ninja is missing. Install mingw-w64-ucrt-x86_64-ninja in MSYS2 UCRT64.
  pause
  exit /b 1
)

set "NUP="
if not "%~1"=="" set "NUP=%~1"
if "%NUP%"=="" (
  echo Select your NUP file...
  for /f "usebackq delims=" %%F in (`powershell -NoProfile -STA -Command "Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.OpenFileDialog; $d.Title='Select your local game .nup file'; $d.Filter='NUP files (*.nup)|*.nup|All files (*.*)|*.*'; if($d.ShowDialog() -eq 'OK'){ $d.FileName }"`) do set "NUP=%%F"
)
if not defined NUP (
  echo No file selected.
  pause
  exit /b 1
)
if not exist "%NUP%" (
  echo ERROR: File not found: "%NUP%"
  pause
  exit /b 1
)

echo.
echo Reading NUP package table...
py -3.14 tools\extract_nup.py --input "%NUP%" --list
if errorlevel 1 goto :error
echo.
set /p "PKG=Enter package index to extract: "
if not defined PKG goto :error

echo.
echo Building ZBIC decompressor...
py -3.14 tools\build_zbic.py
if errorlevel 1 goto :error

echo.
echo Extracting selected package and verifying its hashes...
py -3.14 tools\extract_nup.py --input "%NUP%" --package %PKG% --verify
if errorlevel 1 goto :error

for /d %%D in (build\extracted\v*) do if exist "%%D\extraction-manifest.json" set "EXTRACTED=%%D"
if not defined EXTRACTED (
  echo ERROR: Could not locate extracted package manifest.
  goto :error
)
for %%D in ("!EXTRACTED!") do set "VERSION=%%~nxD"
set "VERSION=!VERSION:~1!"
echo Selected build directory: !EXTRACTED!
echo.

echo Generating C from the local ExeFS. This can take a long time...
py -3.14 recomp\gen.py --exefs "!EXTRACTED!\exefs" --out "generated\v!VERSION!"
if errorlevel 1 goto :error

echo.
echo Compiling and linking oot.exe...
py -3.14 tools\build_game.py --version "v!VERSION!" --full-build
if errorlevel 1 goto :error

echo.
echo SUCCESS: build\v!VERSION!\oot.exe
echo Game data and generated game code stayed local on this PC.
pause
exit /b 0

:error
echo.
echo BUILD FAILED. Read the error above; no game file was uploaded.
pause
exit /b 1
