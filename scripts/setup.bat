@echo off
REM =============================================================================
REM setup.bat - First-time setup for offline deployment (Windows)
REM =============================================================================
REM Run this once on a new machine to load pre-saved Docker images and verify
REM the environment is ready. Requires Docker Desktop to be installed.
REM
REM Usage:
REM   scripts\setup.bat
REM =============================================================================

setlocal enabledelayedexpansion

REM Resolve project directory (parent of scripts/)
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"
popd

set "IMAGES_DIR=%PROJECT_DIR%\images"
set "MODELS_DIR=%PROJECT_DIR%\models"

echo ======================================
echo  AI Survival - First-Time Setup
echo ======================================
echo.

REM ---------------------------------------------------------------------------
REM 1. Check Docker
REM ---------------------------------------------------------------------------
echo [1/4] Checking Docker...

where docker >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo   ERROR: Docker is not installed or not in PATH.
    echo   Install Docker Desktop: https://docs.docker.com/desktop/install/windows/
    pause
    exit /b 1
)

docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo   ERROR: Docker daemon is not running.
    echo   Please start Docker Desktop and try again.
    pause
    exit /b 1
)

echo   Docker is ready.
echo.

REM ---------------------------------------------------------------------------
REM 2. Load pre-saved Docker images (offline mode)
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
    for %%f in ("%MODELS_DIR%\*.gguf") do (
        echo     - %%~nxf
    )

    REM Verify DEFAULT_MODEL from .env exists
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

docker image inspect ai-survival-llama-server >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   Image ai-survival-llama-server already exists.
    goto setup_done
)

docker image inspect ai-survival-llama >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   Image ai-survival-llama already exists.
    goto setup_done
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
echo  Next steps:
if %MODEL_COUNT% equ 0 (
    echo    1. Download a model:  scripts\download-models.sh  ^(Git Bash^)
    echo    2. Start the stack:   scripts\start.bat
) else (
    echo    Start the stack:  scripts\start.bat
)
echo.
echo ======================================
echo.

endlocal
pause
