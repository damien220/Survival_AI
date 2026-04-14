#!/usr/bin/env bash
# =============================================================================
# install-local.sh - Install llama.cpp and Open WebUI locally (no Docker)
# =============================================================================
# Installs llama.cpp pre-built binary and Open WebUI (Python package) directly
# on the host system without Docker. Useful when Docker is unavailable.
#
# Usage:
#   ./scripts/install-local.sh           # Full install
#   ./scripts/install-local.sh --check   # Check install status only
#
# Requirements:
#   - Python 3.11+ (for Open WebUI)
#   - curl or wget (for downloads if not pre-cached)
#   - Internet access OR pre-downloaded files in installers/local/
#
# Pre-cached files (for fully offline install):
#   installers/local/llama-cpp/linux/   <- llama.cpp zip for Linux
#   installers/local/llama-cpp/macos/   <- llama.cpp zip for macOS
#   installers/local/open-webui/        <- open-webui wheel(s)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BIN_DIR="$PROJECT_DIR/bin"
VENV_DIR="$PROJECT_DIR/data/webui-venv"
LOCAL_CACHE="$PROJECT_DIR/installers/local"
MODELS_DIR="$PROJECT_DIR/models"

# llama.cpp version (match Dockerfile.llamacpp)
LLAMA_VERSION="b8586"
LLAMA_BASE_URL="https://github.com/ggerganov/llama.cpp/releases/download/${LLAMA_VERSION}"

echo "======================================"
echo " AI Survival - Local Installation"
echo "======================================"
echo ""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
check_cmd() { command -v "$1" &>/dev/null; }

download_file() {
    local url="$1" dest="$2" label="$3"
    echo "  Downloading $label ..."
    if check_cmd curl; then
        curl -L --progress-bar -C - -o "$dest" "$url" || return 1
    elif check_cmd wget; then
        wget -q --show-progress -c -O "$dest" "$url" || return 1
    else
        echo "  ERROR: Neither curl nor wget found."
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Detect OS/arch
# ---------------------------------------------------------------------------
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux*)  PLATFORM="linux" ;;
    Darwin*) PLATFORM="macos" ;;
    *)
        echo "ERROR: Unsupported platform: $OS"
        echo "Use scripts/install-local.bat on Windows."
        exit 1 ;;
esac

case "$ARCH" in
    x86_64|amd64) ARCH_TAG="x64" ;;
    arm64|aarch64) ARCH_TAG="arm64" ;;
    *) ARCH_TAG="x64" ;;
esac

echo "Platform: $PLATFORM ($ARCH)"
echo ""

# ---------------------------------------------------------------------------
# --check mode: report status without installing
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--check" ]; then
    echo "Installation status:"
    echo ""
    LLAMA_BIN="$BIN_DIR/llama-cpp/llama-server"
    if [ -x "$LLAMA_BIN" ]; then
        VER=$("$LLAMA_BIN" --version 2>/dev/null | head -1 || echo "unknown")
        echo "  llama.cpp:    INSTALLED  ($LLAMA_BIN)"
        echo "               Version: $VER"
    else
        echo "  llama.cpp:    NOT installed"
    fi

    if [ -d "$VENV_DIR" ] && "$VENV_DIR/bin/python" -c "import open_webui" &>/dev/null 2>&1; then
        echo "  Open WebUI:   INSTALLED  ($VENV_DIR)"
    else
        echo "  Open WebUI:   NOT installed"
    fi

    if check_cmd python3; then
        PY_VER=$(python3 --version 2>&1)
        echo "  Python:       $PY_VER"
    else
        echo "  Python:       NOT found"
    fi
    echo ""
    exit 0
fi

mkdir -p "$BIN_DIR/llama-cpp"
mkdir -p "$LOCAL_CACHE/llama-cpp"
mkdir -p "$LOCAL_CACHE/open-webui"

# ---------------------------------------------------------------------------
# STEP 1: Install llama.cpp binary
# ---------------------------------------------------------------------------
echo "[1/3] Installing llama.cpp (${LLAMA_VERSION})..."
LLAMA_BIN="$BIN_DIR/llama-cpp/llama-server"

if [ -x "$LLAMA_BIN" ]; then
    echo "  Already installed at: $LLAMA_BIN"
else
    # Determine zip filename for this platform
    if [ "$PLATFORM" = "linux" ]; then
        LLAMA_ZIP="llama-${LLAMA_VERSION}-bin-ubuntu-x64.zip"
    elif [ "$PLATFORM" = "macos" ]; then
        if [ "$ARCH_TAG" = "arm64" ]; then
            LLAMA_ZIP="llama-${LLAMA_VERSION}-bin-macos-arm64.zip"
        else
            LLAMA_ZIP="llama-${LLAMA_VERSION}-bin-macos-x64.zip"
        fi
    fi

    LLAMA_ZIP_PATH="$LOCAL_CACHE/llama-cpp/$PLATFORM/$LLAMA_ZIP"
    mkdir -p "$LOCAL_CACHE/llama-cpp/$PLATFORM"

    # Check cache first
    if [ -f "$LLAMA_ZIP_PATH" ]; then
        echo "  Found cached archive: $LLAMA_ZIP"
    else
        echo "  Not found in cache. Downloading from GitHub..."
        LLAMA_URL="${LLAMA_BASE_URL}/${LLAMA_ZIP}"
        if ! download_file "$LLAMA_URL" "$LLAMA_ZIP_PATH" "$LLAMA_ZIP"; then
            echo ""
            echo "  ERROR: Could not download llama.cpp."
            echo "  Manual option: download the zip from:"
            echo "    https://github.com/ggerganov/llama.cpp/releases/tag/${LLAMA_VERSION}"
            echo "  And place it in: $LOCAL_CACHE/llama-cpp/$PLATFORM/"
            echo "  Then re-run this script."
            exit 1
        fi
    fi

    # Extract
    echo "  Extracting..."
    EXTRACT_TMP="$BIN_DIR/llama-cpp/tmp-extract"
    mkdir -p "$EXTRACT_TMP"
    unzip -q -o "$LLAMA_ZIP_PATH" -d "$EXTRACT_TMP"

    # Find llama-server binary in extracted files
    FOUND_BIN=$(find "$EXTRACT_TMP" -name "llama-server" -type f 2>/dev/null | head -1)
    if [ -z "$FOUND_BIN" ]; then
        # Some builds name it llama-server.exe or have different structure
        FOUND_BIN=$(find "$EXTRACT_TMP" -name "llama-server*" -type f 2>/dev/null | head -1)
    fi

    if [ -z "$FOUND_BIN" ]; then
        echo "  ERROR: llama-server binary not found in the archive."
        echo "  Contents of archive:"
        find "$EXTRACT_TMP" -type f | head -20
        rm -rf "$EXTRACT_TMP"
        exit 1
    fi

    # Copy binary and shared libs to bin dir
    cp "$FOUND_BIN" "$LLAMA_BIN"
    chmod +x "$LLAMA_BIN"

    # Copy any .so / .dylib files needed (shared libs)
    find "$EXTRACT_TMP" -name "*.so*" -o -name "*.dylib" 2>/dev/null | while read -r lib; do
        cp "$lib" "$BIN_DIR/llama-cpp/"
    done

    rm -rf "$EXTRACT_TMP"
    echo "  Installed: $LLAMA_BIN"
fi

echo ""

# ---------------------------------------------------------------------------
# STEP 2: Install Open WebUI (Python venv)
# ---------------------------------------------------------------------------
echo "[2/3] Installing Open WebUI..."

# Check Python
if ! check_cmd python3; then
    echo "  ERROR: python3 not found."
    echo "  Please install Python 3.11 or later: https://www.python.org/downloads/"
    exit 1
fi

PY_VER=$(python3 -c "import sys; print(sys.version_info[:2])")
PY_MAJOR=$(python3 -c "import sys; print(sys.version_info.major)")
PY_MINOR=$(python3 -c "import sys; print(sys.version_info.minor)")

if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 11 ]; }; then
    echo "  ERROR: Python 3.11+ required. Found: Python ${PY_MAJOR}.${PY_MINOR}"
    echo "  Please install Python 3.11+: https://www.python.org/downloads/"
    exit 1
fi

echo "  Python: $(python3 --version)"

# Create venv if needed
if [ ! -d "$VENV_DIR" ]; then
    echo "  Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Check if open-webui already installed
if "$VENV_DIR/bin/python" -c "import open_webui" &>/dev/null 2>&1; then
    VER=$("$VENV_DIR/bin/pip" show open-webui 2>/dev/null | grep Version | awk '{print $2}')
    echo "  Open WebUI already installed (v$VER)."
else
    # Check for pre-downloaded wheels
    WHEEL_COUNT=$(find "$LOCAL_CACHE/open-webui" -name "*.whl" 2>/dev/null | wc -l)
    if [ "$WHEEL_COUNT" -gt 0 ]; then
        echo "  Installing from cached wheels ($WHEEL_COUNT wheel(s))..."
        "$VENV_DIR/bin/pip" install --no-index --find-links="$LOCAL_CACHE/open-webui" open-webui
    else
        echo "  Installing open-webui from PyPI (requires internet)..."
        echo "  This may take several minutes..."
        "$VENV_DIR/bin/pip" install --upgrade pip --quiet
        "$VENV_DIR/bin/pip" install open-webui
    fi
    echo "  Open WebUI installed."
fi

echo ""

# ---------------------------------------------------------------------------
# STEP 3: Write local .env config (if not present)
# ---------------------------------------------------------------------------
echo "[3/3] Writing local configuration..."

LOCAL_ENV="$PROJECT_DIR/.env.local"
if [ ! -f "$LOCAL_ENV" ]; then
    cat > "$LOCAL_ENV" << EOF
# Local (non-Docker) configuration for AI Survival
# Used by start-local.sh

LLAMA_PORT=8080
WEBUI_PORT=3000
CONTEXT_SIZE=4096
GPU_LAYERS=0
THREADS=0
BATCH_SIZE=512
WEBUI_AUTH=false

# Disable features that require internet or extra model downloads
ENABLE_OLLAMA_API=false
ENABLE_OPENAI_API=true
ENABLE_RAG_WEB_SEARCH=false
DO_NOT_TRACK=true
SCARF_NO_ANALYTICS=true
EOF
    echo "  Created: $LOCAL_ENV"
else
    echo "  Already exists: $LOCAL_ENV"
fi

echo ""
echo "======================================"
echo " Installation complete!"
echo "======================================"
echo ""
echo " Start:  ./scripts/start-local.sh"
echo " Stop:   ./scripts/stop-local.sh"
echo ""
echo " Models: Place .gguf files in $MODELS_DIR"
echo ""
