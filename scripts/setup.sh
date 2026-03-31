#!/usr/bin/env bash
# =============================================================================
# setup.sh - First-time setup for offline deployment
# =============================================================================
# Run this once on a new machine to load pre-saved Docker images and verify
# the environment is ready. Requires Docker to be installed.
#
# Usage:
#   ./scripts/setup.sh
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGES_DIR="$PROJECT_DIR/images"
MODELS_DIR="$PROJECT_DIR/models"

echo "======================================"
echo " AI Survival - First-Time Setup"
echo "======================================"
echo ""

# ---------------------------------------------------------------------------
# 1. Check Docker
# ---------------------------------------------------------------------------
echo "[1/4] Checking Docker..."

if ! command -v docker &>/dev/null; then
    echo "  ERROR: Docker is not installed."
    echo "  Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker info &>/dev/null 2>&1; then
    echo "  ERROR: Docker daemon is not running."
    echo "  Start Docker Desktop or run: sudo systemctl start docker"
    exit 1
fi

echo "  Docker is ready."
echo ""

# ---------------------------------------------------------------------------
# 2. Load pre-saved Docker images (offline mode)
# ---------------------------------------------------------------------------
echo "[2/4] Loading Docker images..."

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

    # Verify DEFAULT_MODEL from .env exists
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
# 4. Build llama-server image (if not already loaded)
# ---------------------------------------------------------------------------
echo "[4/4] Checking llama-server image..."

if docker image inspect ai-survival-llama-server &>/dev/null 2>&1; then
    echo "  Image ai-survival-llama-server already exists."
elif docker image inspect ai-survival-llama &>/dev/null 2>&1; then
    echo "  Image ai-survival-llama already exists."
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
echo " Next steps:"
if [ "$MODEL_COUNT" -eq 0 ]; then
    echo "   1. Download a model:  ./scripts/download-models.sh"
    echo "   2. Start the stack:   ./scripts/start.sh"
else
    echo "   Start the stack:  ./scripts/start.sh"
fi
echo ""
echo "======================================"
