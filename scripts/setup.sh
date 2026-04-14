#!/usr/bin/env bash
# =============================================================================
# setup.sh - First-time setup for AI Survival
# =============================================================================
# Prompts for installation type (Docker or Local), then runs the appropriate
# setup. Run this once on a new machine before starting the stack.
#
# Usage:
#   ./scripts/setup.sh
#   ./scripts/setup.sh --docker   # Skip prompt, use Docker mode
#   ./scripts/setup.sh --local    # Skip prompt, use local mode
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGES_DIR="$PROJECT_DIR/images"
MODELS_DIR="$PROJECT_DIR/models"
DOCKER_INSTALLERS_DIR="$PROJECT_DIR/installers/docker"

echo "======================================"
echo " AI Survival - Setup"
echo "======================================"
echo ""

# ---------------------------------------------------------------------------
# Choose installation mode
# ---------------------------------------------------------------------------
MODE="${1:-}"

if [ -z "$MODE" ]; then
    echo " Choose installation type:"
    echo ""
    echo "   [D] Docker  — runs llama.cpp and Open WebUI in containers"
    echo "                 (recommended, requires Docker Desktop or Engine)"
    echo ""
    echo "   [L] Local   — runs llama.cpp and Open WebUI directly on this machine"
    echo "                 (no Docker needed, requires Python 3.11+)"
    echo ""
    read -r -p " Enter choice [D/L]: " CHOICE
    case "$CHOICE" in
        d|D) MODE="--docker" ;;
        l|L) MODE="--local"  ;;
        *)
            echo "Invalid choice. Run again and enter D or L."
            exit 1 ;;
    esac
fi

# ---------------------------------------------------------------------------
# LOCAL mode — delegate to install-local.sh
# ---------------------------------------------------------------------------
if [ "$MODE" = "--local" ]; then
    echo ""
    echo " Starting local installation..."
    echo ""
    exec "$SCRIPT_DIR/install-local.sh"
fi

# ---------------------------------------------------------------------------
# DOCKER mode
# ---------------------------------------------------------------------------
echo ""
echo "======================================"
echo " AI Survival - Docker Setup"
echo "======================================"
echo ""

# ---------------------------------------------------------------------------
# 1. Check Docker
# ---------------------------------------------------------------------------
echo "[1/4] Checking Docker..."

DOCKER_OK=1

if ! command -v docker &>/dev/null; then
    DOCKER_OK=0
    echo ""
    echo "  WARNING: Docker is not installed on this machine."
    echo ""

    # Check if installers are already downloaded
    INSTALLER_FOUND=0
    for f in "$DOCKER_INSTALLERS_DIR"/windows/*.exe \
              "$DOCKER_INSTALLERS_DIR"/macos/*.dmg \
              "$DOCKER_INSTALLERS_DIR"/linux/*.tgz; do
        [ -f "$f" ] && INSTALLER_FOUND=1 && break
    done

    if [ $INSTALLER_FOUND -eq 1 ]; then
        echo "  Docker installers found in installers/docker/"
        echo "  Install Docker from there, then re-run this script."
        echo ""
        echo "    Windows: installers/docker/windows/DockerDesktopInstaller.exe"
        echo "    macOS:   installers/docker/macos/DockerDesktop-*.dmg"
        echo "    Linux:   see installers/docker/linux/README.md"
    else
        echo "  To install Docker offline, first download the installer:"
        echo ""
        echo "    ./scripts/download-docker.sh"
        echo ""
        echo "  Or install Docker directly (requires internet):"
        echo "    https://docs.docker.com/get-docker/"
        echo ""
        echo "  Alternatively, use local mode (no Docker):"
        echo "    ./scripts/setup.sh --local"
    fi
    echo ""
    echo "  Skipping Docker-specific setup steps."
    echo ""
elif ! docker info &>/dev/null 2>&1; then
    DOCKER_OK=0
    echo "  WARNING: Docker daemon is not running."
    echo "  Start Docker Desktop or run: sudo systemctl start docker"
    echo "  Skipping Docker-specific setup steps."
    echo ""
else
    echo "  Docker is ready."
    echo ""
fi

# ---------------------------------------------------------------------------
# 2. Load pre-saved Docker images (only if Docker is running)
# ---------------------------------------------------------------------------
echo "[2/4] Loading Docker images..."

if [ $DOCKER_OK -eq 0 ]; then
    echo "  Skipped (Docker not available)."
else
    LOADED=0
    if [ -d "$IMAGES_DIR" ]; then
        for tar_file in "$IMAGES_DIR"/*.tar; do
            [ -f "$tar_file" ] || continue
            echo "  Loading: $(basename "$tar_file")..."
            docker load -i "$tar_file"
            LOADED=$((LOADED + 1))
        done
    fi

    if [ $LOADED -eq 0 ]; then
        echo "  No image tars found in $IMAGES_DIR/"
        echo "  Images will be built/pulled on first start (requires internet)."
    else
        echo "  Loaded $LOADED image(s)."
    fi
fi
echo ""

# ---------------------------------------------------------------------------
# 3. Check models
# ---------------------------------------------------------------------------
echo "[3/4] Checking models..."

MODEL_COUNT=$(find "$MODELS_DIR" -name "*.gguf" 2>/dev/null | wc -l)

if [ "$MODEL_COUNT" -eq 0 ]; then
    echo "  WARNING: No .gguf models found in $MODELS_DIR/"
    echo "  Run ./scripts/download-models.sh to download models."
else
    echo "  Found $MODEL_COUNT model(s):"
    for f in "$MODELS_DIR"/*.gguf; do
        [ -f "$f" ] || continue
        SIZE=$(du -h "$f" | cut -f1)
        echo "    - $(basename "$f") ($SIZE)"
    done

    if [ -f "$PROJECT_DIR/.env" ]; then
        DEFAULT_MODEL=$(grep -E '^DEFAULT_MODEL=' "$PROJECT_DIR/.env" 2>/dev/null | cut -d= -f2)
        if [ -n "$DEFAULT_MODEL" ] && [ ! -f "$MODELS_DIR/$DEFAULT_MODEL" ]; then
            echo ""
            echo "  WARNING: DEFAULT_MODEL=$DEFAULT_MODEL not found."
            echo "  Update DEFAULT_MODEL in .env to match an available model."
        fi
    fi
fi
echo ""

# ---------------------------------------------------------------------------
# 4. Build llama-server image (only if Docker is running)
# ---------------------------------------------------------------------------
echo "[4/4] Checking llama-server image..."

if [ $DOCKER_OK -eq 0 ]; then
    echo "  Skipped (Docker not available)."
elif docker image inspect ai-survival-llama-server &>/dev/null 2>&1 || \
     docker image inspect ai-survival-llama &>/dev/null 2>&1; then
    echo "  Image already exists."
else
    echo "  Image not found. Building from Dockerfile (this may take a few minutes)..."
    cd "$PROJECT_DIR"
    docker build -f Dockerfile.llamacpp -t ai-survival-llama .
    echo "  Build complete."
fi

echo ""
echo "======================================"
echo " Setup complete!"
echo "======================================"
echo ""

if [ $DOCKER_OK -eq 0 ]; then
    echo " Docker is not installed. Next steps:"
    echo "   1. Download Docker installer: ./scripts/download-docker.sh"
    echo "   2. Install Docker, then re-run: ./scripts/setup.sh --docker"
    echo "   OR use local mode:             ./scripts/setup.sh --local"
elif [ "$MODEL_COUNT" -eq 0 ]; then
    echo " Next steps:"
    echo "   1. Download a model:  ./scripts/download-models.sh"
    echo "   2. Start the stack:   ./scripts/start.sh"
else
    echo " Start the stack:  ./scripts/start.sh"
fi
echo ""
echo "======================================"
