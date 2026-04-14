#!/usr/bin/env bash
# =============================================================================
# start-local.sh - Start llama.cpp and Open WebUI locally (no Docker)
# =============================================================================
# Runs llama-server and open-webui directly on the host, no containers.
# Requires install-local.sh to have been run first.
#
# Usage:
#   ./scripts/start-local.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BIN_DIR="$PROJECT_DIR/bin/llama-cpp"
VENV_DIR="$PROJECT_DIR/data/webui-venv"
MODELS_DIR="$PROJECT_DIR/models"
PIDS_DIR="$PROJECT_DIR/data/pids"
LOGS_DIR="$PROJECT_DIR/data/logs"
LOCAL_ENV="$PROJECT_DIR/.env.local"
ENV_FILE="$PROJECT_DIR/.env"

echo "======================================"
echo " AI Survival (Local) - Starting..."
echo "======================================"
echo ""

# ---------------------------------------------------------------------------
# Load configuration
# ---------------------------------------------------------------------------
load_env() {
    local file="$1"
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        # Export the variable
        export "${line?}"
    done < "$file"
}

# Load .env first (shared settings like DEFAULT_MODEL), then .env.local overrides
[ -f "$ENV_FILE" ]    && load_env "$ENV_FILE"
[ -f "$LOCAL_ENV" ]   && load_env "$LOCAL_ENV"

LLAMA_PORT="${LLAMA_PORT:-8080}"
WEBUI_PORT="${WEBUI_PORT:-3000}"
CONTEXT_SIZE="${CONTEXT_SIZE:-4096}"
GPU_LAYERS="${GPU_LAYERS:-0}"
THREADS="${THREADS:-0}"
BATCH_SIZE="${BATCH_SIZE:-512}"
DEFAULT_MODEL="${DEFAULT_MODEL:-}"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
LLAMA_SERVER="$BIN_DIR/llama-server"
if [ ! -x "$LLAMA_SERVER" ]; then
    echo "ERROR: llama-server not found at $LLAMA_SERVER"
    echo "Run first: ./scripts/install-local.sh"
    exit 1
fi

if [ ! -d "$VENV_DIR" ] || ! "$VENV_DIR/bin/python" -c "import open_webui" &>/dev/null 2>&1; then
    echo "ERROR: Open WebUI not installed in $VENV_DIR"
    echo "Run first: ./scripts/install-local.sh"
    exit 1
fi

# Find model
if [ -n "$DEFAULT_MODEL" ] && [ -f "$MODELS_DIR/$DEFAULT_MODEL" ]; then
    MODEL_FILE="$MODELS_DIR/$DEFAULT_MODEL"
else
    MODEL_FILE=$(find "$MODELS_DIR" -name "*.gguf" 2>/dev/null | head -1)
fi

if [ -z "$MODEL_FILE" ] || [ ! -f "$MODEL_FILE" ]; then
    echo "ERROR: No .gguf model found in $MODELS_DIR/"
    echo "Run: ./scripts/download-models.sh"
    exit 1
fi

echo "Model:     $(basename "$MODEL_FILE")"
echo "llama API: http://localhost:${LLAMA_PORT}"
echo "WebUI:     http://localhost:${WEBUI_PORT}"
echo ""

# Check port conflicts
check_port() {
    local port="$1" name="$2"
    if ss -tlnp 2>/dev/null | grep -q ":${port} " || \
       netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
        echo "ERROR: Port $port ($name) is already in use."
        echo "Update $name in .env.local or stop the conflicting process."
        exit 1
    fi
}
check_port "$LLAMA_PORT" "LLAMA_PORT"
check_port "$WEBUI_PORT" "WEBUI_PORT"

# Create dirs
mkdir -p "$PIDS_DIR"
mkdir -p "$LOGS_DIR"

# Stop any previous leftover processes
"$SCRIPT_DIR/stop-local.sh" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Start llama-server
# ---------------------------------------------------------------------------
echo "Starting llama-server..."

# Build argument array — handles model paths with spaces correctly
LLAMA_ARGS=(
    --model "$MODEL_FILE"
    --host 0.0.0.0
    --port "$LLAMA_PORT"
    --ctx-size "$CONTEXT_SIZE"
    --batch-size "$BATCH_SIZE"
)
if [ "$GPU_LAYERS" != "0" ]; then
    LLAMA_ARGS+=(--n-gpu-layers "$GPU_LAYERS")
fi
if [ "$THREADS" != "0" ]; then
    LLAMA_ARGS+=(--threads "$THREADS")
fi

# Set library paths so shared libs in bin/llama-cpp/ are found
export LD_LIBRARY_PATH="$BIN_DIR:${LD_LIBRARY_PATH:-}"
export DYLD_LIBRARY_PATH="$BIN_DIR:${DYLD_LIBRARY_PATH:-}"

nohup "$LLAMA_SERVER" "${LLAMA_ARGS[@]}" > "$LOGS_DIR/llama-server.log" 2>&1 &
LLAMA_PID=$!
echo "$LLAMA_PID" > "$PIDS_DIR/llama.pid"
echo "  PID: $LLAMA_PID  (log: data/logs/llama-server.log)"

# ---------------------------------------------------------------------------
# Start Open WebUI
# ---------------------------------------------------------------------------
echo "Starting Open WebUI..."

export OPENAI_API_BASE_URLS="http://localhost:${LLAMA_PORT}/v1"
export OPENAI_API_KEYS="none"
export WEBUI_AUTH="${WEBUI_AUTH:-false}"
export ENABLE_OLLAMA_API="false"
export ENABLE_OPENAI_API="true"
export ENABLE_RAG_WEB_SEARCH="false"
export DO_NOT_TRACK="true"
export SCARF_NO_ANALYTICS="true"
export DATA_DIR="$PROJECT_DIR/data/webui-data"
mkdir -p "$DATA_DIR"

nohup "$VENV_DIR/bin/open-webui" serve \
    --host 0.0.0.0 \
    --port "$WEBUI_PORT" \
    > "$LOGS_DIR/open-webui.log" 2>&1 &
WEBUI_PID=$!
echo "$WEBUI_PID" > "$PIDS_DIR/webui.pid"
echo "  PID: $WEBUI_PID  (log: data/logs/open-webui.log)"

echo ""

# ---------------------------------------------------------------------------
# Wait for llama-server to be ready
# ---------------------------------------------------------------------------
echo "Waiting for llama-server to be ready..."
MAX_WAIT=300
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if curl -sf "http://localhost:${LLAMA_PORT}/health" &>/dev/null; then
        echo " Ready!"
        break
    fi
    if ! kill -0 "$LLAMA_PID" 2>/dev/null; then
        echo ""
        echo "ERROR: llama-server stopped unexpectedly."
        echo "Check logs: cat data/logs/llama-server.log"
        exit 1
    fi
    printf "."
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo ""
    echo "WARNING: Timed out waiting for llama-server. It may still be loading."
    echo "Check: cat data/logs/llama-server.log"
fi

echo ""
echo "======================================"
echo " AI Survival (Local) is running!"
echo "======================================"
echo ""
echo " Open WebUI:  http://localhost:${WEBUI_PORT}"
echo " llama API:   http://localhost:${LLAMA_PORT}"
echo ""
echo " Logs:  data/logs/llama-server.log"
echo "        data/logs/open-webui.log"
echo ""
echo " Stop:  ./scripts/stop-local.sh"
echo "======================================"
echo ""

# Try to open browser
if command -v xdg-open &>/dev/null; then
    xdg-open "http://localhost:${WEBUI_PORT}" 2>/dev/null &
elif command -v open &>/dev/null; then
    open "http://localhost:${WEBUI_PORT}" 2>/dev/null &
fi
