# AI Survival

A fully offline, portable AI assistant on an external HDD/USB. Plug it into any machine with Docker, run one script, and chat with a local LLM through a browser-based UI. No internet required.

## How It Works

- **llama.cpp** runs the LLM inference (OpenAI-compatible API)
- **Open WebUI** provides the browser chat interface
- **Docker Compose** orchestrates both as containers
- **GGUF models** are stored on the HDD, loaded at startup

```
External HDD
├── llama.cpp server (Docker)  ←── serves the model
├── Open WebUI (Docker)        ←── chat UI at localhost:3000
└── models/*.gguf              ←── offline model files
```

## Quick Start

### 1. First-time setup

```bash
cd /path/to/AI_Survival
./scripts/setup.sh
```

### 2. Download a model (requires internet, one-time)

```bash
./scripts/download-models.sh
```

### 3. Start

```bash
# Linux / macOS
./scripts/start.sh

# Windows
scripts\start.bat
```

Open **http://localhost:3000** and start chatting.

### Stop

```bash
./scripts/stop.sh        # Linux / macOS
scripts\stop.bat         # Windows
```

## Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| RAM | 4 GB | 16 GB |
| Storage | 32 GB (system + 1 model) | 128 GB (multiple models) |
| CPU | Any modern x86_64 | Multi-core for faster inference |
| GPU | Not required | NVIDIA with CUDA for acceleration |
| Software | Docker Engine 20.10+ | Docker Desktop (Win/Mac) |

## Available Models

| Model | Size | Best For |
|-------|------|----------|
| TinyLlama 1.1B | ~669 MB | Low-RAM systems, quick testing |
| Phi-3 Mini 3.8B | ~2.4 GB | Good quality, moderate resources |
| Mistral 7B Instruct | ~4.4 GB | Strong general-purpose |
| Llama 3.1 8B Instruct | ~4.9 GB | Best quality |

Download models interactively:
```bash
./scripts/download-models.sh          # Interactive menu
./scripts/download-models.sh --list   # List available models
```

Switch between downloaded models:
```bash
./scripts/switch-model.sh
```

## GPU Acceleration

For NVIDIA GPUs with CUDA support:

```bash
./scripts/start.sh --gpu
```

Set `GPU_LAYERS=-1` in `.env` to offload all layers to GPU. Requires [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html).

## Offline Deployment

See [OFFLINE.md](OFFLINE.md) for the full guide on preparing the HDD and deploying without internet.

Summary:
1. **Prepare** (online machine): download models, build Docker images, save as tars
2. **Copy** the entire `AI_Survival/` directory to the external HDD
3. **Deploy** (offline machine): plug in, run `setup.sh`, then `start.sh`

## Configuration

All settings are in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `DEFAULT_MODEL` | `tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf` | Active model filename |
| `WEBUI_PORT` | `3000` | Open WebUI port |
| `LLAMA_PORT` | `8080` | llama.cpp API port |
| `CONTEXT_SIZE` | `4096` | Context window (tokens) |
| `GPU_LAYERS` | `0` | GPU layers (0=CPU, -1=all) |
| `THREADS` | `0` | CPU threads (0=auto) |
| `BATCH_SIZE` | `512` | Prompt batch size |

## Adding Custom Models

1. Download any GGUF model from [Hugging Face](https://huggingface.co/models?sort=trending&search=gguf)
2. Place the `.gguf` file in the `models/` directory
3. Switch to it: `./scripts/switch-model.sh <filename.gguf>`

See [models/README.md](models/README.md) for more details.

## Validation

Run the validation checklist to verify everything is ready:

```bash
./scripts/validate.sh
```

This checks project structure, configs, models, Docker images, and system requirements.

## Scripts Reference

| Script | Description |
|--------|-------------|
| `scripts/start.sh` / `start.bat` | Start the stack (add `--gpu` for CUDA) |
| `scripts/stop.sh` / `stop.bat` | Stop the stack |
| `scripts/setup.sh` | First-time setup (load images, verify models) |
| `scripts/download-models.sh` | Download GGUF models from Hugging Face |
| `scripts/switch-model.sh` | Switch the active model |
| `scripts/save-images.sh` | Export Docker images as tars for offline use |
| `scripts/validate.sh` | Pre-deployment validation checklist |

## FAQ

**Q: Do I need internet to use this?**
No. Once the HDD is prepared (models downloaded, Docker images saved), everything runs offline. You only need Docker installed on the target machine.

**Q: How much RAM do I need?**
4 GB minimum (TinyLlama only). 8 GB for 3B-7B models. 16 GB for comfortable 8B model usage.

**Q: Can I use my own models?**
Yes. Any GGUF model compatible with llama.cpp works. Drop it in `models/` and switch to it.

**Q: The server takes a long time to start.**
Large models (7B+) take 30-60 seconds to load, especially on CPU. The start script waits up to 5 minutes. Check progress with: `docker logs -f ai-survival-llama`

**Q: Port 3000 or 8080 is already in use.**
Change `WEBUI_PORT` or `LLAMA_PORT` in `.env` to an available port.

**Q: How do I update llama.cpp?**
Edit `LLAMA_CPP_VERSION` in `Dockerfile.llamacpp`, rebuild (`docker compose build`), and re-export (`scripts/save-images.sh`).

## Project Structure

```
AI_Survival/
├── Dockerfile.llamacpp          # llama.cpp server image (multi-stage build)
├── docker-compose.yml           # Main orchestration
├── docker-compose.gpu.yml       # GPU override
├── .env                         # Configuration
├── .dockerignore                # Build context exclusions
├── models/                      # GGUF model files
├── data/                        # Open WebUI persistent data
├── images/                      # Saved Docker image tars
├── config/                      # Server configuration reference
├── scripts/                     # All automation scripts
├── Dependencies/                # Pre-packaged utility wheels
├── OFFLINE.md                   # Offline deployment guide
├── plan.md                      # Implementation plan
└── README.md                    # This file
```

## License

This project assembles open-source components. See individual model licenses in [models/README.md](models/README.md).
