@echo off
REM =============================================================================
REM setup.bat - First-time setup for AI Survival (Windows)
REM =============================================================================
REM Prompts for installation type (Docker or Local), then runs the appropriate
REM setup. Run this once on a new machine before starting the stack.
REM
REM Usage:
REM   scripts\setup.bat
REM   scripts\setup.bat --docker   - Skip prompt, use Docker mode
REM   scripts\setup.bat --local    - Skip prompt, use local mode
REM =============================================================================

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"
popd

set "IMAGES_DIR=%PROJECT_DIR%\images"
set "MODELS_DIR=%PROJECT_DIR%\models"
set "DOCKER_INSTALLERS_DIR=%PROJECT_DIR%\installers\docker"

echo ======================================
echo  AI Survival - Setup
echo ======================================
echo.

REM ---------------------------------------------------------------------------
REM Choose installation mode
REM ---------------------------------------------------------------------------
set "MODE=%~1"

if "%MODE%"=="" (
    echo  Choose installation type:
    echo.
    echo    [D] Docker  -- runs llama.cpp and Open WebUI in containers
    echo                   ^(recommended, requires Docker Desktop^)
    echo.
    echo    [L] Local   -- runs llama.cpp and Open WebUI directly on this machine
    echo                   ^(no Docker needed, requires Python 3.11+^)
    echo.
    set /p "CHOICE= Enter choice [D/L]: "
    if /i "!CHOICE!"=="d" set "MODE=--docker"
    if /i "!CHOICE!"=="l" set "MODE=--local"
    if "!MODE!"=="" (
        echo Invalid choice. Run again and enter D or L.
        pause
        exit /b 1
    )
)

REM ---------------------------------------------------------------------------
REM LOCAL mode — delegate to install-local.bat
REM ---------------------------------------------------------------------------
if "%MODE%"=="--local" (
    echo.
    echo  Starting local installation...
    echo.
    call "%SCRIPT_DIR%install-local.bat"
    goto :eof
)

REM ---------------------------------------------------------------------------
REM DOCKER mode
REM ---------------------------------------------------------------------------
echo.
echo ======================================
echo  AI Survival - Docker Setup
echo ======================================
echo.

REM ---------------------------------------------------------------------------
REM 1. Check Docker
REM ---------------------------------------------------------------------------
echo [1/4] Checking Docker...

set "DOCKER_OK=1"

where docker >nul 2>&1
if %ERRORLEVEL% neq 0 (
    set "DOCKER_OK=0"
    echo.
    echo   WARNING: Docker is not installed on this machine.
    echo.

    REM Check if installers are already downloaded
    set "INSTALLER_FOUND=0"
    if exist "%DOCKER_INSTALLERS_DIR%\windows\*.exe" set "INSTALLER_FOUND=1"
    if exist "%DOCKER_INSTALLERS_DIR%\macos\*.dmg"   set "INSTALLER_FOUND=1"

    if "!INSTALLER_FOUND!"=="1" (
        echo   Docker installers found in installers\docker\
        echo   Install Docker from there, then re-run this script.
        echo.
        echo     Windows: installers\docker\windows\DockerDesktopInstaller.exe
        echo     macOS:   installers\docker\macos\DockerDesktop-*.dmg
        echo     Linux:   see installers\docker\linux\README.md
    ) else (
        echo   To install Docker offline, first download the installer:
        echo.
        echo     scripts\download-docker.bat
        echo.
        echo   Or install Docker directly ^(requires internet^):
        echo     https://docs.docker.com/desktop/install/windows/
        echo.
        echo   Alternatively, use local mode ^(no Docker^):
        echo     scripts\setup.bat --local
    )
    echo.
    echo   Skipping Docker-specific setup steps.
    goto :check_models
)

docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    set "DOCKER_OK=0"
    echo   WARNING: Docker daemon is not running.
    echo   Please start Docker Desktop and try again.
    echo   Skipping Docker-specific setup steps.
    goto :check_models
)

echo   Docker is ready.
echo.

REM ---------------------------------------------------------------------------
REM 2. Load pre-saved Docker images
REM ---------------------------------------------------------------------------
echo [2/4] Loading Docker images...

set "LOADED=0"
if exist "%IMAGES_DIR%\" (
    for %%f in ("%IMAGES_DIR%\*.tar") do (
        if exist "%%f" (
            echo   Loading: %%~nxf...
            docker load -i "%%f"
            if !ERRORLEVEL! neq 0 (
                echo   WARNING: Failed to load %%~nxf
            ) else (
                set /a LOADED+=1
            )
        )
    )
)

if %LOADED% equ 0 (
    echo   No image tars found in %IMAGES_DIR%\
    echo   Images will be built/pulled on first start ^(requires internet^).
) else (
    echo   Loaded %LOADED% image^(s^).
)
goto :check_models_header

:check_models
echo [2/4] Loading Docker images...
echo   Skipped ^(Docker not available^).

:check_models_header
echo.

REM ---------------------------------------------------------------------------
REM 3. Check models
REM ---------------------------------------------------------------------------
echo [3/4] Checking models...

set "MODEL_COUNT=0"
if exist "%MODELS_DIR%\" (
    for %%f in ("%MODELS_DIR%\*.gguf") do set /a MODEL_COUNT+=1
)

if %MODEL_COUNT% equ 0 (
    echo   WARNING: No .gguf models found in %MODELS_DIR%\
    echo   Run scripts\download-models.sh ^(Git Bash^) to download models.
) else (
    echo   Found %MODEL_COUNT% model^(s^):
    for %%f in ("%MODELS_DIR%\*.gguf") do echo     - %%~nxf

    if exist "%PROJECT_DIR%\.env" (
        set "DEFAULT_MODEL="
        for /f "tokens=1,2 delims==" %%a in ('findstr /b "DEFAULT_MODEL=" "%PROJECT_DIR%\.env" 2^>nul') do set "DEFAULT_MODEL=%%b"
        if defined DEFAULT_MODEL (
            if not exist "%MODELS_DIR%\!DEFAULT_MODEL!" (
                echo.
                echo   WARNING: DEFAULT_MODEL=!DEFAULT_MODEL! not found in models\
                echo   Update DEFAULT_MODEL in .env to match an available model.
            )
        )
    )
)
echo.

REM ---------------------------------------------------------------------------
REM 4. Check / build llama-server image
REM ---------------------------------------------------------------------------
echo [4/4] Checking llama-server image...

if %DOCKER_OK% equ 0 (
    echo   Skipped ^(Docker not available^).
    goto :setup_done
)

docker image inspect ai-survival-llama-server >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   Image ai-survival-llama-server already exists.
    goto :setup_done
)

docker image inspect ai-survival-llama >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   Image ai-survival-llama already exists.
    goto :setup_done
)

echo   Image not found. Building from Dockerfile ^(this may take a few minutes^)...
cd /d "%PROJECT_DIR%"
docker build -f Dockerfile.llamacpp -t ai-survival-llama .
if %ERRORLEVEL% neq 0 (
    echo   ERROR: Docker build failed. Check the output above.
    pause
    exit /b 1
)
echo   Build complete.

:setup_done
echo.
echo ======================================
echo  Setup complete!
echo ======================================
echo.

if %DOCKER_OK% equ 0 (
    echo  Docker is not installed. Next steps:
    echo    1. Download Docker installer: scripts\download-docker.bat
    echo    2. Install Docker, then re-run: scripts\setup.bat --docker
    echo    OR use local mode:             scripts\setup.bat --local
) else if %MODEL_COUNT% equ 0 (
    echo  Next steps:
    echo    1. Download a model:  scripts\download-models.sh  ^(Git Bash^)
    echo    2. Start the stack:   scripts\start.bat
) else (
    echo  Start the stack:  scripts\start.bat
)
echo.
echo ======================================
echo.

endlocal
pause
