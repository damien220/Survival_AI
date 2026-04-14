@echo off
REM =============================================================================
REM install-local.bat - Install llama.cpp and Open WebUI locally (Windows)
REM =============================================================================
REM Installs llama.cpp pre-built binary and Open WebUI (Python) directly on
REM Windows without Docker.
REM
REM Usage:
REM   scripts\install-local.bat           - Full install
REM   scripts\install-local.bat --check   - Check install status only
REM
REM Requirements:
REM   - Python 3.11+ (https://www.python.org/downloads/)
REM   - curl (built into Windows 10+)
REM   - Internet OR pre-cached files in installers\local\
REM
REM Pre-cached files (for fully offline install):
REM   installers\local\llama-cpp\windows\   <- llama.cpp zip for Windows
REM   installers\local\open-webui\           <- open-webui wheel(s)
REM =============================================================================

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"
popd

set "BIN_DIR=%PROJECT_DIR%\bin"
set "VENV_DIR=%PROJECT_DIR%\data\webui-venv"
set "LOCAL_CACHE=%PROJECT_DIR%\installers\local"
set "MODELS_DIR=%PROJECT_DIR%\models"

set "LLAMA_VERSION=b8586"
set "LLAMA_ZIP=llama-b8586-bin-win-avx2-x64.zip"
set "LLAMA_URL=https://github.com/ggerganov/llama.cpp/releases/download/b8586/llama-b8586-bin-win-avx2-x64.zip"
set "LLAMA_BIN=%BIN_DIR%\llama-cpp\llama-server.exe"

echo ======================================
echo  AI Survival - Local Installation
echo ======================================
echo.

REM ---------------------------------------------------------------------------
REM --check mode
REM ---------------------------------------------------------------------------
if "%~1"=="--check" (
    echo Installation status:
    echo.
    if exist "%LLAMA_BIN%" (
        echo   llama.cpp:    INSTALLED  ^(%LLAMA_BIN%^)
    ) else (
        echo   llama.cpp:    NOT installed
    )
    if exist "%VENV_DIR%\" (
        "%VENV_DIR%\Scripts\python.exe" -c "import open_webui" >nul 2>&1
        if !ERRORLEVEL! equ 0 (
            echo   Open WebUI:   INSTALLED  ^(%VENV_DIR%^)
        ) else (
            echo   Open WebUI:   venv exists but open-webui not installed
        )
    ) else (
        echo   Open WebUI:   NOT installed
    )
    python --version >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        for /f "tokens=*" %%v in ('python --version 2^>^&1') do echo   Python:       %%v
    ) else (
        echo   Python:       NOT found
    )
    echo.
    goto :end
)

REM Create directories
if not exist "%BIN_DIR%\llama-cpp\" mkdir "%BIN_DIR%\llama-cpp"
if not exist "%LOCAL_CACHE%\llama-cpp\windows\" mkdir "%LOCAL_CACHE%\llama-cpp\windows"
if not exist "%LOCAL_CACHE%\open-webui\" mkdir "%LOCAL_CACHE%\open-webui"
if not exist "%PROJECT_DIR%\data\" mkdir "%PROJECT_DIR%\data"

REM ---------------------------------------------------------------------------
REM STEP 1: Install llama.cpp binary
REM ---------------------------------------------------------------------------
echo [1/3] Installing llama.cpp ^(%LLAMA_VERSION%^)...

if exist "%LLAMA_BIN%" (
    echo   Already installed at: %LLAMA_BIN%
) else (
    set "LLAMA_ZIP_PATH=%LOCAL_CACHE%\llama-cpp\windows\%LLAMA_ZIP%"

    REM Check cache first
    if exist "!LLAMA_ZIP_PATH!" (
        echo   Found cached archive: %LLAMA_ZIP%
    ) else (
        echo   Not found in cache. Downloading from GitHub...
        where curl >nul 2>&1
        if %ERRORLEVEL% neq 0 (
            echo   ERROR: curl not found. Cannot download.
            echo   Manually download the zip from:
            echo     https://github.com/ggerganov/llama.cpp/releases/tag/%LLAMA_VERSION%
            echo   File: %LLAMA_ZIP%
            echo   Place it in: %LOCAL_CACHE%\llama-cpp\windows\
            goto :step2
        )
        curl -L --progress-bar -o "!LLAMA_ZIP_PATH!" "%LLAMA_URL%"
        if !ERRORLEVEL! neq 0 (
            echo   ERROR: Download failed.
            goto :step2
        )
    )

    REM Extract using PowerShell (built into Windows 10+)
    echo   Extracting...
    set "EXTRACT_TMP=%BIN_DIR%\llama-cpp\tmp-extract"
    if not exist "!EXTRACT_TMP!\" mkdir "!EXTRACT_TMP!"
    powershell -NoProfile -Command "Expand-Archive -LiteralPath '!LLAMA_ZIP_PATH!' -DestinationPath '!EXTRACT_TMP!' -Force"
    if !ERRORLEVEL! neq 0 (
        echo   ERROR: Extraction failed.
        goto :step2
    )

    REM Find llama-server.exe
    for /r "!EXTRACT_TMP!" %%f in (llama-server.exe) do (
        copy "%%f" "%LLAMA_BIN%" >nul
        echo   Installed: %LLAMA_BIN%
    )

    REM Copy DLLs alongside binary
    for /r "!EXTRACT_TMP!" %%f in (*.dll) do (
        copy "%%f" "%BIN_DIR%\llama-cpp\" >nul 2>&1
    )

    REM Cleanup
    rmdir /s /q "!EXTRACT_TMP!" 2>nul
)

:step2
echo.

REM ---------------------------------------------------------------------------
REM STEP 2: Install Open WebUI (Python venv)
REM ---------------------------------------------------------------------------
echo [2/3] Installing Open WebUI...

REM Check Python
where python >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo   ERROR: Python not found.
    echo   Please install Python 3.11+: https://www.python.org/downloads/
    echo   Make sure to check "Add Python to PATH" during installation.
    goto :step3
)

for /f "tokens=2 delims= " %%v in ('python --version 2^>^&1') do set "PY_VER=%%v"
echo   Python: %PY_VER%

REM Create venv if needed
if not exist "%VENV_DIR%\" (
    echo   Creating virtual environment...
    python -m venv "%VENV_DIR%"
    if !ERRORLEVEL! neq 0 (
        echo   ERROR: Failed to create virtual environment.
        goto :step3
    )
)

REM Check if open-webui already installed
"%VENV_DIR%\Scripts\python.exe" -c "import open_webui" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   Open WebUI already installed.
    goto :step3
)

REM Check for pre-downloaded wheels
set "WHEEL_COUNT=0"
for %%f in ("%LOCAL_CACHE%\open-webui\*.whl") do set /a WHEEL_COUNT+=1

if %WHEEL_COUNT% gtr 0 (
    echo   Installing from cached wheels ^(%WHEEL_COUNT% wheel^(s^)^)...
    "%VENV_DIR%\Scripts\pip.exe" install --no-index --find-links="%LOCAL_CACHE%\open-webui" open-webui
) else (
    echo   Installing open-webui from PyPI ^(requires internet^)...
    echo   This may take several minutes...
    "%VENV_DIR%\Scripts\pip.exe" install --upgrade pip --quiet
    "%VENV_DIR%\Scripts\pip.exe" install open-webui
)
if !ERRORLEVEL! neq 0 (
    echo   ERROR: open-webui installation failed.
) else (
    echo   Open WebUI installed.
)

:step3
echo.

REM ---------------------------------------------------------------------------
REM STEP 3: Write local config
REM ---------------------------------------------------------------------------
echo [3/3] Writing local configuration...

set "LOCAL_ENV=%PROJECT_DIR%\.env.local"
if not exist "%LOCAL_ENV%" (
    (
        echo # Local ^(non-Docker^) configuration for AI Survival
        echo # Used by start-local.bat
        echo.
        echo LLAMA_PORT=8080
        echo WEBUI_PORT=3000
        echo CONTEXT_SIZE=4096
        echo GPU_LAYERS=0
        echo THREADS=0
        echo BATCH_SIZE=512
        echo WEBUI_AUTH=false
        echo.
        echo # Disable features that require internet or extra model downloads
        echo ENABLE_OLLAMA_API=false
        echo ENABLE_OPENAI_API=true
        echo ENABLE_RAG_WEB_SEARCH=false
        echo DO_NOT_TRACK=true
        echo SCARF_NO_ANALYTICS=true
    ) > "%LOCAL_ENV%"
    echo   Created: %LOCAL_ENV%
) else (
    echo   Already exists: %LOCAL_ENV%
)

echo.
echo ======================================
echo  Installation complete!
echo ======================================
echo.
echo  Start:  scripts\start-local.bat
echo  Stop:   scripts\stop-local.bat
echo.
echo  Models: Place .gguf files in %MODELS_DIR%
echo.

:end
endlocal
pause
