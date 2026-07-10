@echo off
setlocal

REM Delega en local-url.sh dentro de WSL2. Ver README.md, seccion
REM "Acceso desde otros dispositivos de la red local".

where wsl >nul 2>nul
if errorlevel 1 (
    echo No se encontro WSL. Ver README.md, seccion "Instalacion en Windows".
    pause
    exit /b 1
)

pushd "%~dp0"
wsl bash -lc "cd \"$(wslpath -u '%cd%')\" && ./local-url.sh %*"
set EXIT_CODE=%ERRORLEVEL%
popd

exit /b %EXIT_CODE%
