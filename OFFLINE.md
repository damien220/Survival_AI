# Offline Deployment Guide

This guide explains how to prepare the AI Survival stack on an internet-connected machine, copy it to an external HDD/USB, and run it fully offline on any target machine.

---

## Overview

The offline workflow has two stages:

1. **Preparation (online)** — build Docker images, download models, save everything to the HDD
2. **Deployment (offline)** — plug in the HDD, load images, start the stack

Once prepared, the HDD is completely self-contained. No internet is required on the target machine — only Docker.

---

## Stage 1: Preparation (Internet-Connected Machine)

### Prerequisites

- Docker Engine 20.10+ (or Docker Desktop)
- Internet access (for pulling/building images and downloading models)
- External HDD/USB with enough free space (32 GB minimum, 128 GB recommended)

### Step 1: Clone or copy the project to the HDD

```bash
# Copy the project to your external drive
cp -r AI_Survival /mnt/external-hdd/AI_Survival
cd /mnt/external-hdd/AI_Survival
```

### Step 2: Download models

Use the interactive download script to choose which models to fetch:

```bash
./scripts/download-models.sh
```

This shows a menu of available models. Pick the ones you want:

| # | Model | Size | Best for |
|---|-------|------|----------|
| 1 | TinyLlama 1.1B | ~669 MB | Low-RAM systems, quick testing |
| 2 | Phi-3 Mini 3.8B | ~2.4 GB | Good quality, moderate size |
| 3 | Mistral 7B v0.3 | ~4.4 GB | Strong general-purpose |
| 4 | Llama 3.1 8B | ~4.9 GB | Best quality |

You can also download individual models directly:

```bash
./scripts/download-models.sh 1    # Download TinyLlama only
./scripts/download-models.sh all  # Download everything
```

Downloads support resume — if interrupted, re-run to continue where it left off.

### Step 3: Build Docker images

```bash
# Build the llama.cpp server image
docker compose build

# Pull the Open WebUI image
docker compose pull open-webui
```

### Step 4: Save Docker images for offline use

```bash
./scripts/save-images.sh
```

This exports the built images as `.tar` files into the `images/` directory:
- `images/llama-server.tar` — the llama.cpp server
- `images/open-webui.tar` — the Open WebUI frontend

### Step 5: Verify the HDD contents

Your HDD should now contain:

```
AI_Survival/
├── images/
│   ├── llama-server.tar     # Docker image (~500 MB - 1 GB)
│   └── open-webui.tar       # Docker image (~1-2 GB)
├── models/
│   └── *.gguf               # One or more model files
├── scripts/
│   ├── setup.sh
│   ├── start.sh / start.bat
│   ├── stop.sh / stop.bat
│   └── ...
├── docker-compose.yml
├── .env
└── ...
```

### Step 6 (optional): Test before deploying

```bash
./scripts/start.sh
# Open http://localhost:3000 — verify everything works
./scripts/stop.sh
```

---

## Stage 2: Deployment (Offline Target Machine)

### Prerequisites on the target machine

- Docker Engine 20.10+ (or Docker Desktop) — **this must be pre-installed**
- 8 GB RAM minimum (16 GB recommended)
- No internet required

### Step 1: Plug in the HDD

Mount or connect the external drive. Navigate to the project:

```bash
# Linux example
cd /media/username/external-hdd/AI_Survival

# macOS example
cd /Volumes/external-hdd/AI_Survival

# Windows (Git Bash or PowerShell)
cd E:\AI_Survival
```

### Step 2: Run first-time setup

```bash
./scripts/setup.sh
```

This will:
1. Verify Docker is running
2. Load the saved Docker images from `images/*.tar` via `docker load`
3. Check that model files exist in `models/`
4. Build the llama-server image if not already loaded

### Step 3: Start the stack

```bash
# Linux / macOS
./scripts/start.sh

# Windows
scripts\start.bat
```

For GPU acceleration (NVIDIA only):
```bash
./scripts/start.sh --gpu
```

### Step 4: Open the chat UI

The script will print the URL and attempt to open your browser. If not:

```
http://localhost:3000
```

### Step 5: Stop when done

```bash
# Linux / macOS
./scripts/stop.sh

# Windows
scripts\stop.bat
```

You can then safely eject the drive.

---

## Updating the HDD

To update models or images on an already-prepared HDD:

### Add a new model
1. Connect the HDD to an internet-connected machine
2. Download the new model: `./scripts/download-models.sh`
3. Update `DEFAULT_MODEL` in `.env` if desired

### Update Docker images
1. Rebuild/re-pull: `docker compose build && docker compose pull open-webui`
2. Re-export: `./scripts/save-images.sh`

### Update llama.cpp version
1. Edit `LLAMA_CPP_VERSION` in `Dockerfile.llamacpp`
2. Rebuild and re-export as above

---

## Troubleshooting

### "No .gguf model files found"
Download at least one model: `./scripts/download-models.sh`

### "Docker daemon is not running"
- **Linux:** `sudo systemctl start docker`
- **Windows/macOS:** Start Docker Desktop

### llama-server is unhealthy
Check logs: `docker logs ai-survival-llama`

Common causes:
- Model file too large for available RAM — try a smaller model
- Corrupted model file — re-download it
- Wrong `DEFAULT_MODEL` in `.env` — verify the filename matches

### Open WebUI shows "connection error"
The llama-server may still be loading (large models take time). Wait and refresh, or check:
```bash
curl http://localhost:8080/health
```

### Port conflicts
If ports 3000 or 8080 are in use, change `WEBUI_PORT` or `LLAMA_PORT` in `.env`.

---

## Disk Space Reference

| Component | Size |
|-----------|------|
| Docker images (tars) | ~2-3 GB |
| TinyLlama 1.1B | ~669 MB |
| Phi-3 Mini 3.8B | ~2.4 GB |
| Mistral 7B | ~4.4 GB |
| Llama 3.1 8B | ~4.9 GB |
| All 4 models + images | ~15-16 GB |
| Project files + scripts | < 1 MB |
