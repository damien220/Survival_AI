#!/usr/bin/env bash
# =============================================================================
# stop.sh - Stop the AI Survival LLM stack (Linux/macOS)
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "======================================"
echo " AI Survival - Stopping..."
echo "======================================"
echo ""

cd "$PROJECT_DIR"

# Detect compose command
if docker compose version &>/dev/null 2>&1; then
    COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then
    COMPOSE="docker-compose"
else
    echo "ERROR: Docker Compose not found."
    exit 1
fi

$COMPOSE down

echo ""
echo "======================================"
echo " All containers stopped."
echo "======================================"
echo ""
echo " You can now safely eject the drive."
echo ""
echo " To eject on Linux:   sudo umount /path/to/drive"
echo " To eject on macOS:   diskutil eject /path/to/drive"
echo "======================================"
