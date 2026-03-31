#!/usr/bin/env bash
# =============================================================================
# validate.sh - Pre-deployment validation checklist
# =============================================================================
# Checks the project structure, configuration, models, and Docker readiness.
# Run this before deploying to a new machine to catch issues early.
#
# Usage:
#   ./scripts/validate.sh
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
WARN=0
FAIL=0

pass()  { PASS=$((PASS + 1)); echo "  [PASS] $1"; }
warn()  { WARN=$((WARN + 1)); echo "  [WARN] $1"; }
fail()  { FAIL=$((FAIL + 1)); echo "  [FAIL] $1"; }

echo "======================================"
echo " AI Survival - Validation Checklist"
echo "======================================"
echo ""

# ---------------------------------------------------------------------------
# 1. Project structure
# ---------------------------------------------------------------------------
echo "[1/6] Project structure..."

for dir in models data scripts config images; do
    if [ -d "$PROJECT_DIR/$dir" ]; then
        pass "$dir/ directory exists"
    else
        fail "$dir/ directory missing"
    fi
done

for file in docker-compose.yml Dockerfile.llamacpp .env; do
    if [ -f "$PROJECT_DIR/$file" ]; then
        pass "$file exists"
    else
        fail "$file missing"
    fi
done

if [ -f "$PROJECT_DIR/docker-compose.gpu.yml" ]; then
    pass "docker-compose.gpu.yml exists (GPU support)"
else
    warn "docker-compose.gpu.yml missing (GPU support unavailable)"
fi
echo ""

# ---------------------------------------------------------------------------
# 2. Scripts
# ---------------------------------------------------------------------------
echo "[2/6] Scripts..."

for script in start.sh stop.sh setup.sh download-models.sh switch-model.sh save-images.sh entrypoint-llama.sh; do
    SPATH="$PROJECT_DIR/scripts/$script"
    if [ -f "$SPATH" ]; then
        if [ -x "$SPATH" ]; then
            if bash -n "$SPATH" 2>/dev/null; then
                pass "$script (exists, executable, valid syntax)"
            else
                fail "$script has syntax errors"
            fi
        else
            warn "$script exists but is not executable (run: chmod +x scripts/$script)"
        fi
    else
        fail "$script missing"
    fi
done

if [ -f "$PROJECT_DIR/scripts/start.bat" ]; then
    pass "start.bat exists (Windows support)"
else
    warn "start.bat missing (no Windows support)"
fi
if [ -f "$PROJECT_DIR/scripts/stop.bat" ]; then
    pass "stop.bat exists (Windows support)"
else
    warn "stop.bat missing (no Windows support)"
fi
echo ""

# ---------------------------------------------------------------------------
# 3. Configuration
# ---------------------------------------------------------------------------
echo "[3/6] Configuration (.env)..."

ENV_FILE="$PROJECT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    for var in DEFAULT_MODEL LLAMA_PORT WEBUI_PORT CONTEXT_SIZE GPU_LAYERS THREADS BATCH_SIZE; do
        if grep -q "^${var}=" "$ENV_FILE"; then
            VAL=$(grep "^${var}=" "$ENV_FILE" | cut -d= -f2)
            pass "$var=$VAL"
        else
            warn "$var not set in .env (will use default)"
        fi
    done
else
    fail ".env file missing"
fi
echo ""

# ---------------------------------------------------------------------------
# 4. Models
# ---------------------------------------------------------------------------
echo "[4/6] Models..."

MODEL_COUNT=$(find "$PROJECT_DIR/models" -name "*.gguf" 2>/dev/null | wc -l)
if [ "$MODEL_COUNT" -eq 0 ]; then
    fail "No .gguf model files found in models/"
else
    for f in "$PROJECT_DIR/models"/*.gguf; do
        [ -f "$f" ] || continue
        SIZE=$(du -h "$f" | cut -f1)
        pass "$(basename "$f") ($SIZE)"
    done

    # Check DEFAULT_MODEL matches an actual file
    DEFAULT_MODEL=$(grep -E '^DEFAULT_MODEL=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)
    if [ -n "$DEFAULT_MODEL" ]; then
        if [ -f "$PROJECT_DIR/models/$DEFAULT_MODEL" ]; then
            pass "DEFAULT_MODEL=$DEFAULT_MODEL exists"
        else
            fail "DEFAULT_MODEL=$DEFAULT_MODEL not found in models/"
        fi
    fi
fi
echo ""

# ---------------------------------------------------------------------------
# 5. Docker images (offline tars)
# ---------------------------------------------------------------------------
echo "[5/6] Offline Docker images..."

TAR_COUNT=0
for tar in "$PROJECT_DIR/images"/*.tar; do
    [ -f "$tar" ] || continue
    TAR_COUNT=$((TAR_COUNT + 1))
    SIZE=$(du -h "$tar" | cut -f1)
    pass "$(basename "$tar") ($SIZE)"
done

if [ "$TAR_COUNT" -eq 0 ]; then
    warn "No image tars in images/ (will need to build/pull on first run — requires internet)"
fi
echo ""

# ---------------------------------------------------------------------------
# 6. Docker environment
# ---------------------------------------------------------------------------
echo "[6/6] Docker environment..."

if command -v docker &>/dev/null; then
    pass "Docker is installed ($(docker --version 2>/dev/null | head -1))"
    if docker info &>/dev/null 2>&1; then
        pass "Docker daemon is running"
    else
        warn "Docker daemon is not running"
    fi
else
    warn "Docker is not installed (required on target machine)"
fi

if docker compose version &>/dev/null 2>&1; then
    pass "Docker Compose available ($(docker compose version --short 2>/dev/null))"
elif command -v docker-compose &>/dev/null; then
    pass "docker-compose available (standalone)"
else
    warn "Docker Compose not found (required on target machine)"
fi

# RAM check
TOTAL_RAM_KB=$(grep -i '^MemTotal:' /proc/meminfo 2>/dev/null | awk '{print $2}')
if [ -n "$TOTAL_RAM_KB" ]; then
    TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
    if [ "$TOTAL_RAM_MB" -ge 8192 ]; then
        pass "System RAM: ${TOTAL_RAM_MB} MB (sufficient)"
    elif [ "$TOTAL_RAM_MB" -ge 4096 ]; then
        warn "System RAM: ${TOTAL_RAM_MB} MB (8 GB+ recommended)"
    else
        fail "System RAM: ${TOTAL_RAM_MB} MB (minimum 4 GB required)"
    fi
fi
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS + WARN + FAIL))
echo "======================================"
echo " Results: $PASS passed, $WARN warnings, $FAIL failed ($TOTAL checks)"
echo "======================================"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo " Fix the failures above before deploying."
    exit 1
elif [ $WARN -gt 0 ]; then
    echo ""
    echo " Warnings are non-blocking but worth reviewing."
    exit 0
else
    echo ""
    echo " All checks passed. Ready to deploy!"
    exit 0
fi
