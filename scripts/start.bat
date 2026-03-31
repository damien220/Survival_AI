@echo off
REM =============================================================================
REM start.bat - Launch the AI Survival LLM stack (Windows)
REM =============================================================================
REM Auto-detects the project directory from the script location so it works
REM regardless of which drive letter the HDD/USB is assigned.
REM
REM Usage:
REM   scripts\start.bat          - CPU mode (default)
REM   scripts\start.bat --gpu    - GPU mode (requires NVIDIA + nvidia-docker2)
REM =============================================================================

setlocal enabledelayedexpansion

REM Resolve project directory (parent of scripts/)
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"
popd

echo ======================================
echo  AI Survival - Starting...
echo ======================================
echo.

REM ---------------------------------------------------------------------------
REM Pre-flight checks
REM ---------------------------------------------------------------------------

REM Check Docker
where docker >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Docker is not installed or not in PATH.
    echo Install Docker Desktop: https://docs.docker.com/desktop/install/windows/
    pause
    exit /b 1
)

REM Check Docker daemon is running
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Docker daemon is not running.
    echo Please start Docker Desktop and try again.
    pause
    exit /b 1
)

REM Check Docker Compose
docker compose version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Docker Compose is not available.
    echo Ensure Docker Desktop is up to date.
    pause
    exit /b 1
)

REM Check system RAM
for /f "tokens=2 delims==" %%m in ('wmic computersystem get TotalPhysicalMemory /value 2^>nul ^| findstr "="') do set "TOTAL_RAM_BYTES=%%m"
if defined TOTAL_RAM_BYTES (
    set /a "TOTAL_RAM_MB=!TOTAL_RAM_BYTES:~0,-6!"
    if !TOTAL_RAM_MB! lss 4096 (
        echo ERROR: At least 4 GB of RAM is required. Detected: !TOTAL_RAM_MB! MB
        pause
        exit /b 1
    )
    if !TOTAL_RAM_MB! lss 8192 (
        echo WARNING: 8 GB+ RAM recommended. Detected: !TOTAL_RAM_MB! MB
        echo Consider using TinyLlama for best results on this system.
    )
)

REM Check for models
set "MODEL_COUNT=0"
for %%f in ("%PROJECT_DIR%\models\*.gguf") do set /a MODEL_COUNT+=1
if %MODEL_COUNT% equ 0 (
    echo WARNING: No .gguf model files found in %PROJECT_DIR%\models\
    echo Run scripts\download-models.sh in Git Bash to download a model first.
    echo.
    set /p "CONFIRM=Continue anyway? (y/N) "
    if /i not "!CONFIRM!"=="y" exit /b 1
)

REM Validate DEFAULT_MODEL exists
set "DEFAULT_MODEL="
for /f "tokens=1,2 delims==" %%a in ('findstr /b "DEFAULT_MODEL=" "%PROJECT_DIR%\.env" 2^>nul') do set "DEFAULT_MODEL=%%b"
if defined DEFAULT_MODEL (
    if %MODEL_COUNT% gtr 0 (
        if not exist "%PROJECT_DIR%\models\!DEFAULT_MODEL!" (
            echo ERROR: DEFAULT_MODEL=!DEFAULT_MODEL! not found in models\
            echo Update DEFAULT_MODEL in .env or run: scripts\switch-model.sh
            pause
            exit /b 1
        )
    )
)

REM ---------------------------------------------------------------------------
REM Build compose command
REM ---------------------------------------------------------------------------
cd /d "%PROJECT_DIR%"

set "COMPOSE_FILES=-f docker-compose.yml"
set "MODE=CPU only"

if "%~1"=="--gpu" (
    if not exist "docker-compose.gpu.yml" (
        echo ERROR: docker-compose.gpu.yml not found.
        pause
        exit /b 1
    )
    set "COMPOSE_FILES=!COMPOSE_FILES! -f docker-compose.gpu.yml"
    set "MODE=GPU (NVIDIA CUDA)"
)

REM Read ports from .env or use defaults
set "WEBUI_PORT=3000"
set "LLAMA_PORT=8080"
for /f "tokens=1,2 delims==" %%a in ('findstr /b "WEBUI_PORT=" .env 2^>nul') do set "WEBUI_PORT=%%b"
for /f "tokens=1,2 delims==" %%a in ('findstr /b "LLAMA_PORT=" .env 2^>nul') do set "LLAMA_PORT=%%b"

REM Check for port conflicts
netstat -ano 2>nul | findstr ":%WEBUI_PORT% " | findstr "LISTENING" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo ERROR: Port %WEBUI_PORT% ^(WEBUI_PORT^) is already in use.
    echo Change WEBUI_PORT in .env or stop the conflicting service.
    pause
    exit /b 1
)
netstat -ano 2>nul | findstr ":%LLAMA_PORT% " | findstr "LISTENING" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo ERROR: Port %LLAMA_PORT% ^(LLAMA_PORT^) is already in use.
    echo Change LLAMA_PORT in .env or stop the conflicting service.
    pause
    exit /b 1
)

echo Mode: %MODE%
echo Project: %PROJECT_DIR%
echo.

REM ---------------------------------------------------------------------------
REM Start services
REM ---------------------------------------------------------------------------
echo Starting containers...
docker compose %COMPOSE_FILES% up -d --build

echo.
echo Waiting for llama-server to be healthy...

REM Wait for health check (up to 5 minutes)
set "MAX_WAIT=60"
set "ELAPSED=0"

:wait_loop
if %ELAPSED% geq %MAX_WAIT% goto wait_timeout

for /f "tokens=*" %%s in ('docker inspect --format="{{.State.Health.Status}}" ai-survival-llama 2^>nul') do set "STATUS=%%s"

if "%STATUS%"=="healthy" goto healthy
if "%STATUS%"=="unhealthy" (
    echo.
    echo ERROR: llama-server is unhealthy. Check logs:
    echo   docker logs ai-survival-llama
    pause
    exit /b 1
)

<nul set /p "=."
timeout /t 5 /nobreak >nul
set /a ELAPSED+=1
goto wait_loop

:wait_timeout
echo.
echo WARNING: Timed out waiting for llama-server.
echo It may still be loading. Check: docker logs ai-survival-llama
goto show_info

:healthy
echo  Ready!

:show_info
echo.
echo ======================================
echo  AI Survival is running!
echo ======================================
echo.
echo  Open WebUI:  http://localhost:%WEBUI_PORT%
echo  Stop with:   scripts\stop.bat
echo.
echo ======================================
echo.

REM Open browser
start "" "http://localhost:%WEBUI_PORT%"

endlocal
