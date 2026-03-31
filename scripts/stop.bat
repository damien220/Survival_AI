@echo off
REM =============================================================================
REM stop.bat - Stop the AI Survival LLM stack (Windows)
REM =============================================================================

setlocal

REM Resolve project directory
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"
popd

echo ======================================
echo  AI Survival - Stopping...
echo ======================================
echo.

cd /d "%PROJECT_DIR%"

docker compose down

echo.
echo ======================================
echo  All containers stopped.
echo ======================================
echo.
echo  You can now safely eject the drive.
echo  Use "Safely Remove Hardware" in the system tray.
echo.
echo ======================================

endlocal
pause
