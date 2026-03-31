#!/usr/bin/env bash
# =============================================================================
# save-images.sh - Save Docker images as tars for offline deployment
# =============================================================================
# Run this AFTER you have built/pulled all images on an internet-connected
# machine. The resulting .tar files in images/ allow fully offline setup.
#
# Usage:
#   ./scripts/save-images.sh
#
# Prerequisites:
#   - Docker images must already exist (run docker compose build first)
#   - Enough disk space in images/ for the tar exports
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGES_DIR="$PROJECT_DIR/images"

echo "======================================"
echo " AI Survival - Save Docker Images"
echo "======================================"
echo ""

mkdir -p "$IMAGES_DIR"

# ---------------------------------------------------------------------------
# Image catalog: LOCAL_NAME | TAR_FILENAME
# ---------------------------------------------------------------------------
declare -a IMAGE_NAMES=(
    "ai-survival-llama"
    "ghcr.io/open-webui/open-webui:main"
)

declare -a TAR_FILES=(
    "llama-server.tar"
    "open-webui.tar"
)

NUM_IMAGES=${#IMAGE_NAMES[@]}
SAVED=0
ERRORS=0

for i in $(seq 0 $((NUM_IMAGES - 1))); do
    IMAGE="${IMAGE_NAMES[$i]}"
    TAR="${TAR_FILES[$i]}"
    DEST="$IMAGES_DIR/$TAR"

    echo "[$((i + 1))/$NUM_IMAGES] $IMAGE -> $TAR"

    # Check image exists
    if ! docker image inspect "$IMAGE" &>/dev/null; then
        echo "  SKIP: Image '$IMAGE' not found locally."
        echo "  Build/pull it first, then re-run this script."
        ERRORS=$((ERRORS + 1))
        echo ""
        continue
    fi

    # Get image size
    SIZE=$(docker image inspect "$IMAGE" --format='{{.Size}}' 2>/dev/null)
    SIZE_MB=$((SIZE / 1024 / 1024))
    echo "  Image size: ~${SIZE_MB} MB"

    # Save
    echo "  Saving to $DEST ..."
    docker save -o "$DEST" "$IMAGE"

    TAR_SIZE=$(du -h "$DEST" | cut -f1)
    echo "  Done: $TAR_SIZE"
    SAVED=$((SAVED + 1))
    echo ""
done

echo "======================================"
echo " Summary"
echo "======================================"
echo "  Saved:  $SAVED / $NUM_IMAGES"
if [ $ERRORS -gt 0 ]; then
    echo "  Missed: $ERRORS (build/pull those images and re-run)"
fi
echo ""
echo "  Tar files in: $IMAGES_DIR/"
ls -lh "$IMAGES_DIR"/*.tar 2>/dev/null || true
echo ""
echo "  These tars are loaded automatically by setup.sh on the target machine."
echo "======================================"
