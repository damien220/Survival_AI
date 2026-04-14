@echo off
REM =============================================================================
REM download-docker.bat - Download Docker installers for offline use (Windows)
REM =============================================================================
REM Downloads Docker Desktop for Windows into installers\docker\windows\
REM for offline installation on target machines.
REM
REM Usage:
REM   scripts\download-docker.bat             - Download Windows installer
REM   scripts\download-docker.bat --all       - All platforms (requires curl)
REM   scripts\download-docker.bat --list      - List already-downloaded installers
REM =============================================================================

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"
popd

set "INSTALLERS_DIR=%PROJECT_DIR%\installers\docker"

REM Installer URLs (always resolves to latest stable Docker Desktop)
set "WIN_URL=https://desktop.docker.com/win/main/amd64/Docker Desktop Installer.exe"
set "MAC_INTEL_URL=https://desktop.docker.com/mac/main/amd64/Docker.dmg"
set "MAC_ARM_URL=https://desktop.docker.com/mac/main/arm64/Docker.dmg"
set "LINUX_VER=27.5.1"
set "LINUX_URL=https://download.docker.com/linux/static/stable/x86_64/docker-27.5.1.tgz"

set "WIN_FILE=%INSTALLERS_DIR%\windows\DockerDesktopInstaller.exe"

echo ======================================
echo  AI Survival - Download Docker
echo ======================================
echo.

REM Create directories
if not exist "%INSTALLERS_DIR%\windows\" mkdir "%INSTALLERS_DIR%\windows"
if not exist "%INSTALLERS_DIR%\macos\"   mkdir "%INSTALLERS_DIR%\macos"
if not exist "%INSTALLERS_DIR%\linux\"   mkdir "%INSTALLERS_DIR%\linux"

REM ---------------------------------------------------------------------------
REM --list mode
REM ---------------------------------------------------------------------------
if "%~1"=="--list" (
    echo Downloaded Docker installers in %INSTALLERS_DIR%\:
    echo.
    set "FOUND=0"
    if exist "%INSTALLERS_DIR%\windows\DockerDesktopInstaller.exe" (
        echo   [Windows]  DockerDesktopInstaller.exe
        set "FOUND=1"
    )
    if exist "%INSTALLERS_DIR%\macos\DockerDesktop-Intel.dmg" (
        echo   [macOS]    DockerDesktop-Intel.dmg
        set "FOUND=1"
    )
    if exist "%INSTALLERS_DIR%\macos\DockerDesktop-ARM.dmg" (
        echo   [macOS]    DockerDesktop-ARM.dmg
        set "FOUND=1"
    )
    if exist "%INSTALLERS_DIR%\linux\docker-!LINUX_VER!-static-x64.tgz" (
        echo   [Linux]    docker-!LINUX_VER!-static-x64.tgz
        set "FOUND=1"
    )
    if "!FOUND!"=="0" (
        echo   No installers found.
        echo   Run: scripts\download-docker.bat [--all]
    )
    echo.
    goto :end
)

REM ---------------------------------------------------------------------------
REM Check for curl (Windows 10+ has it built-in)
REM ---------------------------------------------------------------------------
where curl >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: curl is not available. Cannot download files.
    echo curl is built into Windows 10 version 1803+.
    echo Alternatively, download Docker Desktop manually from:
    echo   https://docs.docker.com/desktop/install/windows/
    echo.
    goto :end
)

REM ---------------------------------------------------------------------------
REM Decide what to download
REM ---------------------------------------------------------------------------
set "DO_WIN=1"
set "DO_MAC=0"
set "DO_LIN=0"

if "%~1"=="--all" (
    set "DO_WIN=1"
    set "DO_MAC=1"
    set "DO_LIN=1"
)

echo Note: Docker Desktop installer is ~700MB-1GB.
echo Saving to: %INSTALLERS_DIR%\
echo.

REM ---------------------------------------------------------------------------
REM Download Windows installer
REM ---------------------------------------------------------------------------
if %DO_WIN% equ 1 (
    echo [Windows] Docker Desktop installer...
    if exist "%WIN_FILE%" (
        echo   SKIP: DockerDesktopInstaller.exe already exists.
    ) else (
        echo   Downloading DockerDesktopInstaller.exe ...
        curl -L --progress-bar -o "%WIN_FILE%" "https://desktop.docker.com/win/main/amd64/Docker%%20Desktop%%20Installer.exe"
        if !ERRORLEVEL! neq 0 (
            echo   ERROR: Download failed.
        ) else (
            echo   Saved: %WIN_FILE%
        )
    )
    echo.
)

REM ---------------------------------------------------------------------------
REM Download macOS installers (requires curl with internet access)
REM ---------------------------------------------------------------------------
if %DO_MAC% equ 1 (
    echo [macOS Intel] Docker Desktop...
    if exist "%INSTALLERS_DIR%\macos\DockerDesktop-Intel.dmg" (
        echo   SKIP: DockerDesktop-Intel.dmg already exists.
    ) else (
        echo   Downloading DockerDesktop-Intel.dmg ...
        curl -L --progress-bar -o "%INSTALLERS_DIR%\macos\DockerDesktop-Intel.dmg" "%MAC_INTEL_URL%"
        if !ERRORLEVEL! neq 0 echo   ERROR: Download failed.
    )
    echo.

    echo [macOS Apple Silicon] Docker Desktop...
    if exist "%INSTALLERS_DIR%\macos\DockerDesktop-ARM.dmg" (
        echo   SKIP: DockerDesktop-ARM.dmg already exists.
    ) else (
        echo   Downloading DockerDesktop-ARM.dmg ...
        curl -L --progress-bar -o "%INSTALLERS_DIR%\macos\DockerDesktop-ARM.dmg" "%MAC_ARM_URL%"
        if !ERRORLEVEL! neq 0 echo   ERROR: Download failed.
    )
    echo.
)

REM ---------------------------------------------------------------------------
REM Download Linux static binaries
REM ---------------------------------------------------------------------------
if %DO_LIN% equ 1 (
    echo [Linux] Docker Engine static binaries ^(v%LINUX_VER%^)...
    set "LINUX_FILE=%INSTALLERS_DIR%\linux\docker-%LINUX_VER%-static-x64.tgz"
    if exist "!LINUX_FILE!" (
        echo   SKIP: docker-%LINUX_VER%-static-x64.tgz already exists.
    ) else (
        echo   Downloading docker-%LINUX_VER%-static-x64.tgz ...
        curl -L --progress-bar -o "!LINUX_FILE!" "%LINUX_URL%"
        if !ERRORLEVEL! neq 0 echo   ERROR: Download failed.
    )
    echo   Linux install instructions: %INSTALLERS_DIR%\linux\README.md
    echo.
)

echo ======================================
echo  Done.
echo ======================================
echo.
echo  Install instructions:
echo    Windows: Run  installers\docker\windows\DockerDesktopInstaller.exe
echo    macOS:   Open installers\docker\macos\DockerDesktop-*.dmg
echo    Linux:   See  installers\docker\linux\README.md
echo.
echo  After installing Docker, run: scripts\setup.bat
echo.

:end
endlocal
pause
