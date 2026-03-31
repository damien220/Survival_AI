#!/usr/bin/env bash
# =============================================================================
# entrypoint-llama.sh - Docker entrypoint for llama-server
# =============================================================================
# Reads environment variables and translates them to llama-server CLI flags.
# =============================================================================
set -e

MODEL_PATH="/models/${DEFAULT_MODEL:-model.gguf}"
HOST="${LLAMA_HOST:-0.0.0.0}"
PORT="${LLAMA_PORT:-8080}"
CTX_SIZE="${CONTEXT_SIZE:-4096}"
N_GPU_LAYERS="${GPU_LAYERS:-0}"
N_THREADS="${THREADS:-0}"
N_BATCH="${BATCH_SIZE:-512}"

# Verify model file exists
if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: Model file not found: $MODEL_PATH"
    echo "Available models in /models/:"
    ls -lh /models/*.gguf 2>/dev/null || echo "  (none)"
    echo ""
    echo "Set DEFAULT_MODEL in .env to a valid filename from ./models/"
    exit 1
fi

echo "======================================"
echo " AI Survival - llama.cpp Server"
echo "======================================"
echo " Model:   $MODEL_PATH"
echo " Host:    $HOST:$PORT"
echo " Context: $CTX_SIZE tokens"
echo " Threads: $N_THREADS (0=auto)"
echo " GPU layers: $N_GPU_LAYERS"
echo " Batch:   $N_BATCH"
echo "======================================"

# Build the command
CMD=(
    llama-server
    --host "$HOST"
    --port "$PORT"
    --model "$MODEL_PATH"
    --ctx-size "$CTX_SIZE"
    --batch-size "$N_BATCH"
)

# Only pass --threads if explicitly set (non-zero)
if [ "$N_THREADS" -gt 0 ] 2>/dev/null; then
    CMD+=(--threads "$N_THREADS")
fi

# Only pass --n-gpu-layers if non-zero
if [ "$N_GPU_LAYERS" -ne 0 ] 2>/dev/null; then
    CMD+=(--n-gpu-layers "$N_GPU_LAYERS")
fi

# Append any extra arguments passed to the container
CMD+=("$@")

echo "Starting: ${CMD[*]}"
exec "${CMD[@]}"
