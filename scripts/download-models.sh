#!/usr/bin/env bash
# =============================================================================
# download-models.sh - Download GGUF models from Hugging Face
# =============================================================================
# Interactive script — lists available models and lets you choose which to
# download. Nothing is downloaded automatically. Requires internet access.
#
# Usage:
#   ./scripts/download-models.sh            # Interactive menu
#   ./scripts/download-models.sh --list     # List models without downloading
#   ./scripts/download-models.sh 1          # Download model #1 directly
#   ./scripts/download-models.sh all        # Download all models
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODELS_DIR="$PROJECT_DIR/models"

# ---------------------------------------------------------------------------
# Model catalog: NAME | FILENAME | URL | SIZE | LICENSE
# ---------------------------------------------------------------------------
declare -a MODEL_NAMES=(
    "TinyLlama 1.1B Chat (Q4_K_M)"
    "Phi-3 Mini 3.8B Instruct (Q4_K_M)"
    "Mistral 7B Instruct v0.3 (Q4_K_M)"
    "Llama 3.1 8B Instruct (Q4_K_M)"
)

declare -a MODEL_FILES=(
    "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
    "Phi-3-mini-4k-instruct-Q4_K_M.gguf"
    "Mistral-7B-Instruct-v0.3-Q4_K_M.gguf"
    "Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"
)

declare -a MODEL_URLS=(
    "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
    "https://huggingface.co/bartowski/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct-Q4_K_M.gguf"
    "https://huggingface.co/bartowski/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/Mistral-7B-Instruct-v0.3-Q4_K_M.gguf"
    "https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"
)

declare -a MODEL_SIZES=(
    "~669 MB"
    "~2.4 GB"
    "~4.4 GB"
    "~4.9 GB"
)

declare -a MODEL_LICENSES=(
    "Apache-2.0"
    "MIT"
    "Apache-2.0"
    "Llama 3.1 Community License"
)

NUM_MODELS=${#MODEL_NAMES[@]}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
print_header() {
    echo "======================================"
    echo " AI Survival - Model Downloader"
    echo "======================================"
    echo " Models directory: $MODELS_DIR"
    echo ""
}

print_model_list() {
    printf "  %-4s %-42s %-10s %-8s %s\n" "#" "Model" "Size" "Status" "License"
    printf "  %-4s %-42s %-10s %-8s %s\n" "---" "------------------------------------------" "----------" "--------" "-------------------------"
    for i in $(seq 0 $((NUM_MODELS - 1))); do
        local status="missing"
        if [ -f "$MODELS_DIR/${MODEL_FILES[$i]}" ]; then
            status="ready"
        fi
        printf "  %-4s %-42s %-10s %-8s %s\n" \
            "$((i + 1))" \
            "${MODEL_NAMES[$i]}" \
            "${MODEL_SIZES[$i]}" \
            "$status" \
            "${MODEL_LICENSES[$i]}"
    done
    echo ""
}

download_model() {
    local idx=$1
    local name="${MODEL_NAMES[$idx]}"
    local file="${MODEL_FILES[$idx]}"
    local url="${MODEL_URLS[$idx]}"
    local size="${MODEL_SIZES[$idx]}"
    local dest="$MODELS_DIR/$file"

    if [ -f "$dest" ]; then
        echo "  [SKIP] $name — already downloaded ($dest)"
        return 0
    fi

    echo "  [DOWNLOAD] $name ($size)"
    echo "  URL: $url"
    echo "  Destination: $dest"
    echo ""

    # Use curl with resume support (-C -) and progress bar
    if command -v curl &>/dev/null; then
        curl -L -C - -o "$dest" --progress-bar "$url"
    elif command -v wget &>/dev/null; then
        wget -c -O "$dest" --show-progress "$url"
    else
        echo "  ERROR: Neither curl nor wget found. Install one and retry."
        return 1
    fi

    if [ -f "$dest" ]; then
        local actual_size
        actual_size=$(du -h "$dest" | cut -f1)
        echo "  [DONE] $name — $actual_size saved to $dest"
    else
        echo "  [FAIL] Download failed for $name"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
mkdir -p "$MODELS_DIR"

# Handle --list flag
if [ "${1:-}" = "--list" ]; then
    print_header
    print_model_list
    exit 0
fi

# Handle direct model number or "all"
if [ -n "${1:-}" ]; then
    if [ "$1" = "all" ]; then
        print_header
        echo "Downloading all models..."
        echo ""
        for i in $(seq 0 $((NUM_MODELS - 1))); do
            download_model "$i"
            echo ""
        done
        echo "Done."
        exit 0
    elif [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le "$NUM_MODELS" ]; then
        print_header
        download_model "$(($1 - 1))"
        exit 0
    else
        echo "Invalid argument: $1"
        echo "Usage: $0 [--list | all | MODEL_NUMBER]"
        exit 1
    fi
fi

# Interactive menu
print_header
print_model_list

echo "Enter model number(s) to download (e.g. '1', '1 3', 'all'), or 'q' to quit:"
read -r choice

if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
    echo "Cancelled."
    exit 0
fi

if [ "$choice" = "all" ]; then
    for i in $(seq 0 $((NUM_MODELS - 1))); do
        download_model "$i"
        echo ""
    done
else
    for num in $choice; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "$NUM_MODELS" ]; then
            download_model "$((num - 1))"
            echo ""
        else
            echo "  [SKIP] Invalid selection: $num"
        fi
    done
fi

echo "Done. Update DEFAULT_MODEL in .env to set the active model."
