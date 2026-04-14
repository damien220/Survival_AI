#!/usr/bin/env bash
# =============================================================================
# stop-local.sh - Stop locally running llama.cpp and Open WebUI
# =============================================================================
# Stops the processes started by start-local.sh using saved PID files.
#
# Usage:
#   ./scripts/stop-local.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PIDS_DIR="$PROJECT_DIR/data/pids"

echo "======================================"
echo " AI Survival (Local) - Stopping..."
echo "======================================"
echo ""

stop_pid() {
    local pid_file="$1"
    local label="$2"

    if [ ! -f "$pid_file" ]; then
        echo "  $label: not running (no PID file)"
        return
    fi

    PID=$(cat "$pid_file" 2>/dev/null)
    if [ -z "$PID" ]; then
        echo "  $label: PID file is empty, removing."
        rm -f "$pid_file"
        return
    fi

    if kill -0 "$PID" 2>/dev/null; then
        echo "  Stopping $label (PID $PID)..."
        kill "$PID" 2>/dev/null
        # Wait up to 10s for graceful shutdown
        for i in $(seq 1 10); do
            kill -0 "$PID" 2>/dev/null || break
            sleep 1
        done
        if kill -0 "$PID" 2>/dev/null; then
            echo "  Force-killing $label (PID $PID)..."
            kill -9 "$PID" 2>/dev/null
        fi
        echo "  Stopped."
    else
        echo "  $label: process $PID is not running."
    fi

    rm -f "$pid_file"
}

stop_pid "$PIDS_DIR/llama.pid"  "llama-server"
stop_pid "$PIDS_DIR/webui.pid"  "open-webui"

echo ""
echo "All local services stopped."
echo ""
