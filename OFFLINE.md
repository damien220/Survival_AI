# Offline Deployment Guide

This guide explains how to prepare the AI Survival stack on an internet-connected machine, copy it to an external HDD/USB, and run it fully offline on any target machine.

Two deployment modes are supported — choose the one that fits your target machine:

| Mode | Requires | Best for |
|------|----------|----------|
| **Docker** | Docker Engine 20.10+ or Docker Desktop | Cross-platform consistency, recommended |
| **Local** | Python 3.11+ | Machines where Docker cannot be installed |

---

## Overview

The offline workflow has two stages:

1. **Preparation (online)** — build/download everything and save it to the HDD
2. **Deployment (offline)** — plug in the HDD and start the stack

---

## Stage 1: Preparation (Internet-Connected Machine)

### Step 1: Clone or copy the project to the HDD

```bash
cp -r AI_Survival /mnt/external-hdd/AI_Survival
cd /mnt/external-hdd/AI_Survival
```

### Step 2: Download models

```bash
./scripts/download-models.sh
```

Interactive menu — pick the models you want:

| # | Model | Size | Best for |
|---|-------|------|----------|
| 1 | TinyLlama 1.1B | ~669 MB | Low-RAM systems, quick testing |
| 2 | Phi-3 Mini 3.8B | ~2.4 GB | Good quality, moderate size |
| 3 | Mistral 7B v0.3 | ~4.4 GB | Strong general-purpose |
| 4 | Llama 3.1 8B | ~4.9 GB | Best quality |

Downloads support resume — re-run to continue an interrupted download.

---

### Docker mode — additional preparation steps

#### Step 3D: Build Docker images

```bash
docker compose build
docker compose pull open-webui
```

#### Step 4D: Save images for offline use

```bash
./scripts/save-images.sh
```

Exports to `images/`:
- `images/llama-server.tar` — llama.cpp server (~500 MB–1 GB)
- `images/open-webui.tar` — Open WebUI frontend (~1–2 GB)

#### Step 5D: Optionally download Docker installers for target machines

If Docker may not be installed on target machines, save the installers now:

```bash
./scripts/download-docker.sh --all        # All platforms
./scripts/download-docker.sh --windows    # Windows only
./scripts/download-docker.sh --linux      # Linux only
./scripts/download-docker.sh --macos      # macOS only
```

Installers are saved to `installers/docker/`:

```
installers/docker/
├── windows/DockerDesktopInstaller.exe   (~700 MB)
├── macos/DockerDesktop-Intel.dmg        (~700 MB)
├── macos/DockerDesktop-ARM.dmg          (~700 MB)
└── linux/docker-*-static-x64.tgz       (~70 MB)
```

---

### Local mode — additional preparation steps

#### Step 3L: Pre-download llama.cpp binary (optional, for fully offline install)

Visit the llama.cpp releases page and download the zip for each target platform:

```
https://github.com/ggerganov/llama.cpp/releases/tag/b8586
```

Place zips in the matching cache directory:

| Platform | File to download | Cache directory |
|----------|-----------------|-----------------|
| Linux x64 | `llama-b8586-bin-ubuntu-x64.zip` | `installers/local/llama-cpp/linux/` |
| macOS ARM | `llama-b8586-bin-macos-arm64.zip` | `installers/local/llama-cpp/macos/` |
| macOS Intel | `llama-b8586-bin-macos-x64.zip` | `installers/local/llama-cpp/macos/` |
| Windows | `llama-b8586-bin-win-avx2-x64.zip` | `installers/local/llama-cpp/windows/` |

#### Step 4L: Pre-download Open WebUI wheels (optional)

```bash
pip download open-webui -d installers/local/open-webui/
```

This saves all required wheels for offline `pip install`.

---

### Step 5: Verify the HDD contents

```
AI_Survival/
├── images/
│   ├── llama-server.tar           # Docker image (Docker mode)
│   └── open-webui.tar             # Docker image (Docker mode)
├── installers/
│   ├── docker/                    # Docker installers (optional)
│   │   ├── windows/DockerDesktopInstaller.exe
│   │   ├── macos/DockerDesktop-*.dmg
│   │   └── linux/docker-*-static-x64.tgz
│   └── local/                     # Local-mode binaries (optional)
│       ├── llama-cpp/{platform}/  # llama.cpp zips
│       └── open-webui/            # pip wheels
├── models/
│   └── *.gguf                     # Model files
├── scripts/
│   └── ...
├── docker-compose.yml
├── .env
└── ...
```

---

## Stage 2: Deployment (Offline Target Machine)

### Step 1: Plug in the HDD and navigate to the project

```bash
# Linux
cd /media/username/external-hdd/AI_Survival

# macOS
cd /Volumes/external-hdd/AI_Survival

# Windows (Git Bash or PowerShell)
cd E:\AI_Survival
```

### Step 2: Run first-time setup

```bash
# Linux / macOS
./scripts/setup.sh

# Windows
scripts\setup.bat
```

You will be prompted to choose installation mode:

```
 Choose installation type:

   [D] Docker  — runs llama.cpp and Open WebUI in containers
                 (recommended, requires Docker Desktop or Engine)

   [L] Local   — runs llama.cpp and Open WebUI directly on this machine
                 (no Docker needed, requires Python 3.11+)

 Enter choice [D/L]:
```

You can also skip the prompt with a flag:

```bash
./scripts/setup.sh --docker
./scripts/setup.sh --local
```

#### If Docker mode is chosen and Docker is not installed

Setup will NOT block or exit. Instead it will:
1. Check `installers/docker/` for pre-downloaded installers and show you where they are
2. If no installers are found, prompt you to run `./scripts/download-docker.sh`
3. Continue checking models so you know the full status

Install Docker from the HDD if an installer is present:
- **Windows:** run `installers\docker\windows\DockerDesktopInstaller.exe`
- **macOS:** open `installers/docker/macos/DockerDesktop-*.dmg` and drag to Applications
- **Linux:** see `installers/docker/linux/README.md`

Then re-run: `./scripts/setup.sh --docker`

#### If Local mode is chosen

Setup calls `install-local.sh` which:
1. Checks `installers/local/llama-cpp/` for a pre-cached binary zip — extracts it
2. If no cache is found, downloads from GitHub (requires internet)
3. Creates a Python venv at `data/webui-venv/` and installs Open WebUI
4. Creates `.env.local` with local-mode settings

### Step 3: Start the stack

**Docker mode:**
```bash
./scripts/start.sh          # Linux/macOS
scripts\start.bat            # Windows
./scripts/start.sh --gpu    # NVIDIA GPU mode
```

**Local mode:**
```bash
./scripts/start-local.sh    # Linux/macOS
scripts\start-local.bat      # Windows
```

### Step 4: Open the chat UI

```
http://localhost:3000
```

The start script opens the browser automatically. If it doesn't, open it manually.

### Step 5: Stop when done

**Docker mode:**
```bash
./scripts/stop.sh            # Linux/macOS
scripts\stop.bat             # Windows
```

**Local mode:**
```bash
./scripts/stop-local.sh      # Linux/macOS
scripts\stop-local.bat       # Windows
```

You can then safely eject the drive.

---

## GPU Acceleration (Docker mode)

For NVIDIA GPUs with CUDA:

```bash
./scripts/start.sh --gpu
```

Set `GPU_LAYERS=-1` in `.env` to offload all layers to GPU. Requires NVIDIA Container Toolkit on the target machine.

---

## Updating the HDD

### Add a new model
1. Connect HDD to an internet-connected machine
2. Download: `./scripts/download-models.sh`
3. Update `DEFAULT_MODEL` in `.env` if desired

### Update Docker images
1. Rebuild/re-pull: `docker compose build && docker compose pull open-webui`
2. Re-export: `./scripts/save-images.sh`

### Update llama.cpp version
1. Edit `LLAMA_CPP_VERSION` in `Dockerfile.llamacpp` (Docker) or `LLAMA_VERSION` in `install-local.sh` (local)
2. Rebuild and re-export / re-run install

---

## Troubleshooting

### "No .gguf model files found"
Download at least one model: `./scripts/download-models.sh`

### "Docker is not installed"
- Check `installers/docker/` for offline installers
- Run `./scripts/download-docker.sh` to download them (requires internet)
- Or switch to local mode: `./scripts/setup.sh --local`

### "Docker daemon is not running"
- **Linux:** `sudo systemctl start docker`
- **Windows/macOS:** Start Docker Desktop

### llama-server is unhealthy (Docker)
```bash
docker logs ai-survival-llama
```
Common causes: model too large for RAM, corrupted model file, wrong `DEFAULT_MODEL` in `.env`.

### llama-server stopped unexpectedly (Local)
```bash
cat data/logs/llama-server.log
```

### Open WebUI shows "connection error"
The llama-server may still be loading. Wait and refresh, or check:
```bash
curl http://localhost:8080/health
```

### Port 3000 or 8080 already in use
- Docker mode: change `WEBUI_PORT` / `LLAMA_PORT` in `.env`
- Local mode: change those values in `.env.local`

### Local install: llama.cpp download fails
Place the correct zip manually in `installers/local/llama-cpp/<platform>/`, then re-run `install-local.sh`.

---

## Disk Space Reference

| Component | Size |
|-----------|------|
| Docker images (tars) | ~2–3 GB |
| Docker Desktop (Windows) | ~700 MB |
| Docker Desktop (macOS) | ~700 MB |
| Docker Engine static (Linux) | ~70 MB |
| TinyLlama 1.1B | ~669 MB |
| Phi-3 Mini 3.8B | ~2.4 GB |
| Mistral 7B | ~4.4 GB |
| Llama 3.1 8B | ~4.9 GB |
| All 4 models + Docker images | ~15–16 GB |
| Project files + scripts | < 5 MB |
