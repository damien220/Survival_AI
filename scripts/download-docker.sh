#!/usr/bin/env bash
# =============================================================================
# download-docker.sh - Download Docker installers for offline use
# =============================================================================
# Downloads Docker Desktop (Windows/macOS) and Docker Engine static binaries
# (Linux) into installers/docker/ for offline installation on target machines.
#
# Usage:
#   ./scripts/download-docker.sh             # Auto-detect current platform
#   ./scripts/download-docker.sh --all       # All platforms
#   ./scripts/download-docker.sh --windows   # Windows only
#   ./scripts/download-docker.sh --macos     # macOS only (Intel + ARM)
#   ./scripts/download-docker.sh --linux     # Linux only
#   ./scripts/download-docker.sh --list      # List already-downloaded installers
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALLERS_DIR="$PROJECT_DIR/installers/docker"

# ---------------------------------------------------------------------------
# Installer URLs  (always resolves to latest stable Docker Desktop)
# Update LINUX_VER to match the latest Docker Engine static release.
# Linux static releases: https://download.docker.com/linux/static/stable/x86_64/
# ---------------------------------------------------------------------------
WIN_URL="https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
MAC_INTEL_URL="https://desktop.docker.com/mac/main/amd64/Docker.dmg"
MAC_ARM_URL="https://desktop.docker.com/mac/main/arm64/Docker.dmg"

LINUX_VER="27.5.1"
LINUX_URL="https://download.docker.com/linux/static/stable/x86_64/docker-${LINUX_VER}.tgz"

WIN_FILE="$INSTALLERS_DIR/windows/DockerDesktopInstaller.exe"
MAC_INTEL_FILE="$INSTALLERS_DIR/macos/DockerDesktop-Intel.dmg"
MAC_ARM_FILE="$INSTALLERS_DIR/macos/DockerDesktop-ARM.dmg"
LINUX_FILE="$INSTALLERS_DIR/linux/docker-${LINUX_VER}-static-x64.tgz"

echo "======================================"
echo " AI Survival - Download Docker"
echo "======================================"
echo ""

# Create target directories
mkdir -p "$INSTALLERS_DIR/windows"
mkdir -p "$INSTALLERS_DIR/macos"
mkdir -p "$INSTALLERS_DIR/linux"

# ---------------------------------------------------------------------------
# --list mode: show what is already downloaded
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--list" ]; then
    echo "Downloaded Docker installers in $INSTALLERS_DIR/:"
    echo ""
    FOUND=0
    if [ -f "$WIN_FILE" ]; then
        echo "  [Windows]  DockerDesktopInstaller.exe  ($(du -h "$WIN_FILE" | cut -f1))"
        FOUND=1
    fi
    if [ -f "$MAC_INTEL_FILE" ]; then
        echo "  [macOS]    DockerDesktop-Intel.dmg      ($(du -h "$MAC_INTEL_FILE" | cut -f1))"
        FOUND=1
    fi
    if [ -f "$MAC_ARM_FILE" ]; then
        echo "  [macOS]    DockerDesktop-ARM.dmg        ($(du -h "$MAC_ARM_FILE" | cut -f1))"
        FOUND=1
    fi
    if [ -f "$LINUX_FILE" ]; then
        echo "  [Linux]    docker-${LINUX_VER}-static-x64.tgz  ($(du -h "$LINUX_FILE" | cut -f1))"
        FOUND=1
    fi
    if [ $FOUND -eq 0 ]; then
        echo "  No installers found."
        echo "  Run: ./scripts/download-docker.sh [--all | --windows | --macos | --linux]"
    fi
    echo ""
    exit 0
fi

# ---------------------------------------------------------------------------
# Download helper
# ---------------------------------------------------------------------------
download_file() {
    local url="$1"
    local dest="$2"
    local label="$3"

    if [ -f "$dest" ]; then
        echo "  SKIP: $label already exists ($(du -h "$dest" | cut -f1))"
        return 0
    fi

    echo "  Downloading $label ..."
    if command -v curl &>/dev/null; then
        curl -L --progress-bar -C - -o "$dest" "$url" || { echo "  ERROR: Download failed."; return 1; }
    elif command -v wget &>/dev/null; then
        wget -q --show-progress -c -O "$dest" "$url" || { echo "  ERROR: Download failed."; return 1; }
    else
        echo "  ERROR: Neither curl nor wget is available. Cannot download."
        return 1
    fi
    echo "  Saved: $dest ($(du -h "$dest" | cut -f1))"
}

# ---------------------------------------------------------------------------
# Detect current platform
# ---------------------------------------------------------------------------
detect_platform() {
    case "$(uname -s)" in
        Linux*)           echo "linux" ;;
        Darwin*)          echo "macos" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)                echo "unknown" ;;
    esac
}

# ---------------------------------------------------------------------------
# Decide what to download
# ---------------------------------------------------------------------------
DO_WIN=0; DO_MAC=0; DO_LIN=0

case "${1:-}" in
    --all)     DO_WIN=1; DO_MAC=1; DO_LIN=1 ;;
    --windows) DO_WIN=1 ;;
    --macos)   DO_MAC=1 ;;
    --linux)   DO_LIN=1 ;;
    "")
        case "$(detect_platform)" in
            windows) DO_WIN=1 ;;
            macos)   DO_MAC=1 ;;
            linux)   DO_LIN=1 ;;
            *)
                echo "ERROR: Cannot auto-detect platform."
                echo "Use --windows, --macos, --linux, or --all."
                exit 1 ;;
        esac
        ;;
    --list) ;;   # handled above
    *)
        echo "Usage: $0 [--all | --windows | --macos | --linux | --list]"
        exit 1 ;;
esac

echo "Note: Docker Desktop installers are ~700MB-1GB each."
echo "Saving to: $INSTALLERS_DIR/"
echo ""

# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------
if [ $DO_WIN -eq 1 ]; then
    echo "[Windows] Docker Desktop installer..."
    download_file "$WIN_URL" "$WIN_FILE" "DockerDesktopInstaller.exe"
    echo ""
fi

if [ $DO_MAC -eq 1 ]; then
    echo "[macOS Intel] Docker Desktop..."
    download_file "$MAC_INTEL_URL" "$MAC_INTEL_FILE" "DockerDesktop-Intel.dmg"
    echo ""
    echo "[macOS Apple Silicon] Docker Desktop..."
    download_file "$MAC_ARM_URL" "$MAC_ARM_FILE" "DockerDesktop-ARM.dmg"
    echo ""
fi

if [ $DO_LIN -eq 1 ]; then
    echo "[Linux] Docker Engine static binaries (v${LINUX_VER})..."
    download_file "$LINUX_URL" "$LINUX_FILE" "docker-${LINUX_VER}-static-x64.tgz"
    echo ""
    echo "  Linux installation instructions: $INSTALLERS_DIR/linux/README.md"
    echo ""
fi

echo "======================================"
echo " Done."
echo "======================================"
echo ""
echo " Install instructions:"
echo "   Windows: Run  installers/docker/windows/DockerDesktopInstaller.exe"
echo "   macOS:   Open installers/docker/macos/DockerDesktop-*.dmg"
echo "   Linux:   See  installers/docker/linux/README.md"
echo ""
echo " After installing Docker, run: ./scripts/setup.sh"
echo ""
