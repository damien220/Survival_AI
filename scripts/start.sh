#!/usr/bin/env bash
# =============================================================================
# start.sh - Launch the AI Survival LLM stack (Linux/macOS)
# =============================================================================
# Auto-detects the project directory from the script location so it works
# regardless of where the HDD/USB is mounted.
#
# Usage:
#   ./scripts/start.sh          # CPU mode (default)
#   ./scripts/start.sh --gpu    # GPU mode (requires NVIDIA + nvidia-docker2)
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
echo "======================================"
echo " AI Survival - Starting..."
echo "======================================"
echo ""

# Check Docker
if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker is not installed or not in PATH."
    echo "Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check Docker daemon is running
if ! docker info &>/dev/null 2>&1; then
    echo "ERROR: Docker daemon is not running."
    echo "Start Docker Desktop or run: sudo systemctl start docker"
    exit 1
fi

# Check Docker Compose (v2 plugin or standalone)
if docker compose version &>/dev/null 2>&1; then
    COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then
    COMPOSE="docker-compose"
else
    echo "ERROR: Docker Compose is not installed."
    echo "Install it: https://docs.docker.com/compose/install/"
    exit 1
fi

# Check available RAM
TOTAL_RAM_KB=$(grep -i '^MemTotal:' /proc/meminfo 2>/dev/null | awk '{print $2}')
if [ -n "$TOTAL_RAM_KB" ]; then
    TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
    echo "System RAM: ${TOTAL_RAM_MB} MB"
    if [ "$TOTAL_RAM_MB" -lt 4096 ]; then
        echo "ERROR: At least 4 GB of RAM is required. Detected: ${TOTAL_RAM_MB} MB"
        exit 1
    elif [ "$TOTAL_RAM_MB" -lt 8192 ]; then
        echo "WARNING: 8 GB+ RAM recommended. Detected: ${TOTAL_RAM_MB} MB"
        echo "Consider using TinyLlama (1.1B) for best results on this system."
    fi
fi

# Check for at least one model
MODEL_COUNT=$(find "$PROJECT_DIR/models" -name "*.gguf" 2>/dev/null | wc -l)
if [ "$MODEL_COUNT" -eq 0 ]; then
    echo "WARNING: No .gguf model files found in $PROJECT_DIR/models/"
    echo "Run ./scripts/download-models.sh to download a model first."
    echo ""
    read -r -p "Continue anyway? (y/N) " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        exit 1
    fi
fi

# Validate DEFAULT_MODEL exists
if [ -f "$PROJECT_DIR/.env" ]; then
    DEFAULT_MODEL=$(grep -E '^DEFAULT_MODEL=' "$PROJECT_DIR/.env" 2>/dev/null | cut -d= -f2)
    if [ -n "$DEFAULT_MODEL" ] && [ "$MODEL_COUNT" -gt 0 ] && [ ! -f "$PROJECT_DIR/models/$DEFAULT_MODEL" ]; then
        echo "ERROR: DEFAULT_MODEL=$DEFAULT_MODEL not found in models/"
        echo "Available models:"
        ls "$PROJECT_DIR/models/"*.gguf 2>/dev/null | xargs -I{} basename {}
        echo ""
        echo "Update DEFAULT_MODEL in .env or run: ./scripts/switch-model.sh"
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Build compose command
# ---------------------------------------------------------------------------
cd "$PROJECT_DIR"

COMPOSE_FILES="-f docker-compose.yml"

if [ "${1:-}" = "--gpu" ]; then
    if [ ! -f "docker-compose.gpu.yml" ]; then
        echo "ERROR: docker-compose.gpu.yml not found."
        exit 1
    fi
    COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.gpu.yml"
    echo "Mode: GPU (NVIDIA CUDA)"
else
    echo "Mode: CPU only"
fi

# Read ports from .env or use defaults
WEBUI_PORT=$(grep -E '^WEBUI_PORT=' .env 2>/dev/null | cut -d= -f2 || echo "3000")
WEBUI_PORT="${WEBUI_PORT:-3000}"
LLAMA_PORT=$(grep -E '^LLAMA_PORT=' .env 2>/dev/null | cut -d= -f2 || echo "8080")
LLAMA_PORT="${LLAMA_PORT:-8080}"

# Check for port conflicts
for PORT_NAME_VAL in "WEBUI_PORT:$WEBUI_PORT" "LLAMA_PORT:$LLAMA_PORT"; do
    PNAME="${PORT_NAME_VAL%%:*}"
    PVAL="${PORT_NAME_VAL##*:}"
    if ss -tlnp 2>/dev/null | grep -q ":${PVAL} " || \
       netstat -tlnp 2>/dev/null | grep -q ":${PVAL} "; then
        echo "ERROR: Port $PVAL ($PNAME) is already in use."
        echo "Change $PNAME in .env or stop the conflicting service."
        exit 1
    fi
done

echo "Project: $PROJECT_DIR"
echo ""

# ---------------------------------------------------------------------------
# Start services
# ---------------------------------------------------------------------------
echo "Starting containers..."
$COMPOSE $COMPOSE_FILES up -d --build

echo ""
echo "Waiting for llama-server to be healthy..."

# Wait for health check (up to 5 minutes for large models)
MAX_WAIT=300
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' ai-survival-llama 2>/dev/null || echo "unknown")
    if [ "$STATUS" = "healthy" ]; then
        break
    fi
    if [ "$STATUS" = "unhealthy" ]; then
        echo ""
        echo "ERROR: llama-server is unhealthy. Check logs:"
        echo "  docker logs ai-survival-llama"
        exit 1
    fi
    printf "."
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo ""
    echo "WARNING: Timed out waiting for llama-server (${MAX_WAIT}s)."
    echo "It may still be loading. Check: docker logs ai-survival-llama"
fi

echo ""
echo "======================================"
echo " AI Survival is running!"
echo "======================================"
echo ""
echo " Open WebUI:  http://localhost:${WEBUI_PORT}"
echo " llama API:   http://localhost:$(grep -E '^LLAMA_PORT=' .env 2>/dev/null | cut -d= -f2 || echo '8080')"
echo ""
echo " Stop with:   ./scripts/stop.sh"
echo "======================================"
echo ""

# Try to open browser
if command -v xdg-open &>/dev/null; then
    xdg-open "http://localhost:${WEBUI_PORT}" 2>/dev/null &
elif command -v open &>/dev/null; then
    open "http://localhost:${WEBUI_PORT}" 2>/dev/null &
fi
