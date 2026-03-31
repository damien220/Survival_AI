#!/usr/bin/env bash
# =============================================================================
# switch-model.sh - Switch the active LLM model
# =============================================================================
# Lists all .gguf files in models/, lets you pick one, updates .env, and
# restarts the llama-server container so the new model takes effect.
#
# Usage:
#   ./scripts/switch-model.sh                   # Interactive menu
#   ./scripts/switch-model.sh --list             # List models without switching
#   ./scripts/switch-model.sh <filename.gguf>    # Switch directly by filename
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODELS_DIR="$PROJECT_DIR/models"
ENV_FILE="$PROJECT_DIR/.env"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
get_current_model() {
    grep -E '^DEFAULT_MODEL=' "$ENV_FILE" 2>/dev/null | cut -d= -f2 || echo "(not set)"
}

list_models() {
    local current
    current=$(get_current_model)

    local idx=0
    local found=0

    echo "  Available models in $MODELS_DIR/:"
    echo ""
    printf "  %-4s %-50s %-10s %s\n" "#" "Filename" "Size" "Status"
    printf "  %-4s %-50s %-10s %s\n" "---" "--------------------------------------------------" "----------" "--------"

    for f in "$MODELS_DIR"/*.gguf; do
        [ -f "$f" ] || continue
        idx=$((idx + 1))
        found=$((found + 1))
        local name
        name=$(basename "$f")
        local size
        size=$(du -h "$f" | cut -f1)
        local status=""
        if [ "$name" = "$current" ]; then
            status="<- active"
        fi
        printf "  %-4s %-50s %-10s %s\n" "$idx" "$name" "$size" "$status"
    done

    if [ $found -eq 0 ]; then
        echo "  (none found)"
        echo ""
        echo "  Download models first: ./scripts/download-models.sh"
    fi

    echo ""
    return $found
}

set_model() {
    local model_file="$1"

    # Verify the file exists
    if [ ! -f "$MODELS_DIR/$model_file" ]; then
        echo "ERROR: Model file not found: $MODELS_DIR/$model_file"
        exit 1
    fi

    local current
    current=$(get_current_model)

    if [ "$model_file" = "$current" ]; then
        echo "Model '$model_file' is already active."
        return 0
    fi

    # Update .env
    if grep -q '^DEFAULT_MODEL=' "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^DEFAULT_MODEL=.*|DEFAULT_MODEL=$model_file|" "$ENV_FILE"
    else
        echo "DEFAULT_MODEL=$model_file" >> "$ENV_FILE"
    fi

    echo "Updated .env: DEFAULT_MODEL=$model_file"
}

restart_llama() {
    echo ""
    echo "Restarting llama-server container..."

    cd "$PROJECT_DIR"

    # Detect compose command
    if docker compose version &>/dev/null 2>&1; then
        COMPOSE="docker compose"
    elif command -v docker-compose &>/dev/null; then
        COMPOSE="docker-compose"
    else
        echo "WARNING: Docker Compose not found. Update .env manually and restart."
        return 1
    fi

    # Restart only the llama-server service
    $COMPOSE up -d --no-deps --force-recreate llama-server

    echo ""
    echo "llama-server is restarting with the new model."
    echo "It may take a moment to load. Check health with:"
    echo "  docker logs -f ai-survival-llama"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

echo "======================================"
echo " AI Survival - Model Switcher"
echo "======================================"
echo ""
echo " Current model: $(get_current_model)"
echo ""

# --list flag
if [ "${1:-}" = "--list" ]; then
    list_models
    exit 0
fi

# Direct filename argument
if [ -n "${1:-}" ] && [ "${1:-}" != "--list" ]; then
    set_model "$1"
    restart_llama
    exit 0
fi

# Interactive menu
list_models
MODEL_COUNT=$?

if [ "$MODEL_COUNT" -eq 0 ]; then
    exit 1
fi

echo "Enter model number to switch to, or 'q' to quit:"
read -r choice

if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
    echo "Cancelled."
    exit 0
fi

if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ]; then
    echo "Invalid selection."
    exit 1
fi

# Resolve the filename from the index
idx=0
selected=""
for f in "$MODELS_DIR"/*.gguf; do
    [ -f "$f" ] || continue
    idx=$((idx + 1))
    if [ "$idx" -eq "$choice" ]; then
        selected=$(basename "$f")
        break
    fi
done

if [ -z "$selected" ]; then
    echo "Invalid selection: $choice"
    exit 1
fi

set_model "$selected"
restart_llama
