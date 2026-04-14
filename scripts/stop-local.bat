@echo off
REM =============================================================================
REM stop-local.bat - Stop locally running llama.cpp and Open WebUI (Windows)
REM =============================================================================
REM Stops the processes started by start-local.bat.
REM
REM Usage:
REM   scripts\stop-local.bat
REM   scripts\stop-local.bat --quiet   (no output, used by start-local.bat)
REM =============================================================================

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"
popd

set "PIDS_DIR=%PROJECT_DIR%\data\pids"
set "QUIET=0"
if "%~1"=="--quiet" set "QUIET=1"

if %QUIET% equ 0 (
    echo ======================================
    echo  AI Survival (Local) - Stopping...
    echo ======================================
    echo.
)

REM ---------------------------------------------------------------------------
REM Stop by PID file
REM ---------------------------------------------------------------------------
call :stop_pid "%PIDS_DIR%\llama.pid" "llama-server"
call :stop_pid "%PIDS_DIR%\webui.pid" "open-webui"

REM Also kill any orphaned processes by name (belt-and-suspenders)
tasklist /fi "IMAGENAME eq llama-server.exe" /nh 2>nul | findstr "llama-server.exe" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    if %QUIET% equ 0 echo   Killing orphaned llama-server.exe processes...
    taskkill /f /im "llama-server.exe" >nul 2>&1
)

if %QUIET% equ 0 (
    echo.
    echo All local services stopped.
    echo.
    pause
)
goto :eof

REM ---------------------------------------------------------------------------
:stop_pid
REM %1 = pid file path, %2 = label
REM ---------------------------------------------------------------------------
set "PID_FILE=%~1"
set "LABEL=%~2"

if not exist "%PID_FILE%" (
    if %QUIET% equ 0 echo   %LABEL%: not running ^(no PID file^)
    exit /b
)

set /p PROC_PID= < "%PID_FILE%"
if not defined PROC_PID (
    if %QUIET% equ 0 echo   %LABEL%: PID file is empty, removing.
    del /f "%PID_FILE%" 2>nul
    exit /b
)

if %QUIET% equ 0 echo   Stopping %LABEL% ^(PID !PROC_PID!^)...
taskkill /pid !PROC_PID! /f >nul 2>&1
del /f "%PID_FILE%" 2>nul
if %QUIET% equ 0 echo   Stopped.
exit /b

endlocal
