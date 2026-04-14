@echo off
REM =============================================================================
REM start-local.bat - Start llama.cpp and Open WebUI locally (Windows)
REM =============================================================================
REM Runs llama-server.exe and open-webui directly on Windows without Docker.
REM Requires install-local.bat to have been run first.
REM
REM Usage:
REM   scripts\start-local.bat
REM =============================================================================

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"
popd

set "BIN_DIR=%PROJECT_DIR%\bin\llama-cpp"
set "VENV_DIR=%PROJECT_DIR%\data\webui-venv"
set "MODELS_DIR=%PROJECT_DIR%\models"
set "PIDS_DIR=%PROJECT_DIR%\data\pids"
set "LOGS_DIR=%PROJECT_DIR%\data\logs"
set "ENV_FILE=%PROJECT_DIR%\.env"
set "LOCAL_ENV=%PROJECT_DIR%\.env.local"

echo ======================================
echo  AI Survival (Local) - Starting...
echo ======================================
echo.

REM ---------------------------------------------------------------------------
REM Load configuration from .env and .env.local
REM ---------------------------------------------------------------------------
set "LLAMA_PORT=8080"
set "WEBUI_PORT=3000"
set "CONTEXT_SIZE=4096"
set "GPU_LAYERS=0"
set "THREADS=0"
set "BATCH_SIZE=512"
set "DEFAULT_MODEL="

for %%f in ("%ENV_FILE%" "%LOCAL_ENV%") do (
    if exist "%%f" (
        for /f "usebackq tokens=1,* delims==" %%a in ("%%f") do (
            set "%%a=%%b"
        )
    )
)

REM ---------------------------------------------------------------------------
REM Pre-flight checks
REM ---------------------------------------------------------------------------
if not exist "%BIN_DIR%\llama-server.exe" (
    echo ERROR: llama-server.exe not found at %BIN_DIR%\
    echo Run first: scripts\install-local.bat
    pause
    exit /b 1
)

if not exist "%VENV_DIR%\Scripts\python.exe" (
    echo ERROR: Python venv not found at %VENV_DIR%\
    echo Run first: scripts\install-local.bat
    pause
    exit /b 1
)

REM Find model
set "MODEL_FILE="
if defined DEFAULT_MODEL (
    if exist "%MODELS_DIR%\%DEFAULT_MODEL%" set "MODEL_FILE=%MODELS_DIR%\%DEFAULT_MODEL%"
)
if not defined MODEL_FILE (
    for %%f in ("%MODELS_DIR%\*.gguf") do (
        if not defined MODEL_FILE set "MODEL_FILE=%%f"
    )
)
if not defined MODEL_FILE (
    echo ERROR: No .gguf model found in %MODELS_DIR%\
    echo Run: scripts\download-models.sh ^(Git Bash^)
    pause
    exit /b 1
)

echo Model:     %MODEL_FILE%
echo llama API: http://localhost:%LLAMA_PORT%
echo WebUI:     http://localhost:%WEBUI_PORT%
echo.

REM Check port conflicts
netstat -ano 2>nul | findstr ":%LLAMA_PORT% " | findstr "LISTENING" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo ERROR: Port %LLAMA_PORT% ^(LLAMA_PORT^) is already in use.
    pause
    exit /b 1
)
netstat -ano 2>nul | findstr ":%WEBUI_PORT% " | findstr "LISTENING" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo ERROR: Port %WEBUI_PORT% ^(WEBUI_PORT^) is already in use.
    pause
    exit /b 1
)

REM Create dirs
if not exist "%PIDS_DIR%\" mkdir "%PIDS_DIR%"
if not exist "%LOGS_DIR%\" mkdir "%LOGS_DIR%"
if not exist "%PROJECT_DIR%\data\webui-data\" mkdir "%PROJECT_DIR%\data\webui-data"

REM Stop previous instances
call "%SCRIPT_DIR%stop-local.bat" --quiet 2>nul

REM ---------------------------------------------------------------------------
REM Start llama-server
REM ---------------------------------------------------------------------------
echo Starting llama-server...

set "LLAMA_ARGS=--model "%MODEL_FILE%" --host 0.0.0.0 --port %LLAMA_PORT% --ctx-size %CONTEXT_SIZE% --batch-size %BATCH_SIZE%"
if not "%GPU_LAYERS%"=="0" set "LLAMA_ARGS=%LLAMA_ARGS% --n-gpu-layers %GPU_LAYERS%"
if not "%THREADS%"=="0" set "LLAMA_ARGS=%LLAMA_ARGS% --threads %THREADS%"

REM Add bin dir to PATH so DLLs are found
set "PATH=%BIN_DIR%;%PATH%"

start "llama-server" /B "%BIN_DIR%\llama-server.exe" %LLAMA_ARGS% > "%LOGS_DIR%\llama-server.log" 2>&1

REM Capture PID using WMIC after short delay
timeout /t 2 /nobreak >nul
for /f "tokens=2 delims=," %%p in ('tasklist /fi "IMAGENAME eq llama-server.exe" /fo csv /nh 2^>nul') do (
    set "LLAMA_PID=%%~p"
    goto :got_llama_pid
)
:got_llama_pid
if defined LLAMA_PID (
    echo !LLAMA_PID! > "%PIDS_DIR%\llama.pid"
    echo   PID: !LLAMA_PID!  ^(log: data\logs\llama-server.log^)
) else (
    echo   Started  ^(log: data\logs\llama-server.log^)
)

REM ---------------------------------------------------------------------------
REM Start Open WebUI
REM ---------------------------------------------------------------------------
echo Starting Open WebUI...

set "OPENAI_API_BASE_URLS=http://localhost:%LLAMA_PORT%/v1"
set "OPENAI_API_KEYS=none"
set "WEBUI_AUTH=false"
set "ENABLE_OLLAMA_API=false"
set "ENABLE_OPENAI_API=true"
set "ENABLE_RAG_WEB_SEARCH=false"
set "DO_NOT_TRACK=true"
set "SCARF_NO_ANALYTICS=true"
set "DATA_DIR=%PROJECT_DIR%\data\webui-data"

start "open-webui" /B "%VENV_DIR%\Scripts\open-webui.exe" serve --host 0.0.0.0 --port %WEBUI_PORT% > "%LOGS_DIR%\open-webui.log" 2>&1

timeout /t 2 /nobreak >nul
for /f "tokens=2 delims=," %%p in ('tasklist /fi "IMAGENAME eq open-webui.exe" /fo csv /nh 2^>nul') do (
    set "WEBUI_PID=%%~p"
    goto :got_webui_pid
)
:got_webui_pid
if defined WEBUI_PID (
    echo !WEBUI_PID! > "%PIDS_DIR%\webui.pid"
    echo   PID: !WEBUI_PID!  ^(log: data\logs\open-webui.log^)
) else (
    echo   Started  ^(log: data\logs\open-webui.log^)
)

echo.

REM ---------------------------------------------------------------------------
REM Wait for llama-server to be ready
REM ---------------------------------------------------------------------------
echo Waiting for llama-server to be ready...
set "MAX_WAIT=60"
set "ELAPSED=0"

:wait_loop
if %ELAPSED% geq %MAX_WAIT% goto wait_timeout
curl -sf "http://localhost:%LLAMA_PORT%/health" >nul 2>&1
if !ERRORLEVEL! equ 0 goto ready
<nul set /p "=."
timeout /t 5 /nobreak >nul
set /a ELAPSED+=1
goto wait_loop

:wait_timeout
echo.
echo WARNING: Timed out waiting for llama-server.
echo Check: type data\logs\llama-server.log
goto show_info

:ready
echo  Ready!

:show_info
echo.
echo ======================================
echo  AI Survival (Local) is running!
echo ======================================
echo.
echo  Open WebUI:  http://localhost:%WEBUI_PORT%
echo  llama API:   http://localhost:%LLAMA_PORT%
echo.
echo  Logs:  data\logs\llama-server.log
echo         data\logs\open-webui.log
echo.
echo  Stop:  scripts\stop-local.bat
echo ======================================
echo.

start "" "http://localhost:%WEBUI_PORT%"

endlocal
