@echo off
setlocal

REM Laravel Sail solo corre sobre WSL2 en Windows (Docker Desktop expone
REM el motor ahi). Este .bat delega la ejecucion real a start.sh dentro
REM de tu distro de WSL2. Ver README.md, seccion "Instalacion en Windows".

where wsl >nul 2>nul
if errorlevel 1 (
    echo.
    echo No se encontro WSL. Este proyecto necesita WSL2 para correr Laravel Sail en Windows.
    echo Instalalo desde PowerShell como administrador con: wsl --install
    echo Segui las instrucciones completas en README.md, seccion "Instalacion en Windows".
    echo.
    pause
    exit /b 1
)

pushd "%~dp0"
wsl bash -lc "cd \"$(wslpath -u '%cd%')\" && ./start.sh"
set EXIT_CODE=%ERRORLEVEL%
popd

exit /b %EXIT_CODE%
