# Models

This directory holds GGUF model files used by the llama.cpp server.

## How to add models

1. **Using the download script (recommended):**
   ```bash
   ./scripts/download-models.sh          # Interactive menu
   ./scripts/download-models.sh --list   # List available models
   ./scripts/download-models.sh 1        # Download model #1
   ```

2. **Manual download:** Download any GGUF file and place it in this directory. Then set `DEFAULT_MODEL` in `.env` to its filename.

3. **Custom models:** Any GGUF-format model compatible with llama.cpp can be used. Drop the file here and update `.env`.

## Recommended Models

| # | Model | File | Size | License | Source |
|---|-------|------|------|---------|--------|
| 1 | TinyLlama 1.1B Chat | `tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf` | ~669 MB | Apache-2.0 | [TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF](https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF) |
| 2 | Phi-3 Mini 3.8B Instruct | `Phi-3-mini-4k-instruct-Q4_K_M.gguf` | ~2.4 GB | MIT | [bartowski/Phi-3-mini-4k-instruct-GGUF](https://huggingface.co/bartowski/Phi-3-mini-4k-instruct-GGUF) |
| 3 | Mistral 7B Instruct v0.3 | `Mistral-7B-Instruct-v0.3-Q4_K_M.gguf` | ~4.4 GB | Apache-2.0 | [bartowski/Mistral-7B-Instruct-v0.3-GGUF](https://huggingface.co/bartowski/Mistral-7B-Instruct-v0.3-GGUF) |
| 4 | Llama 3.1 8B Instruct | `Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf` | ~4.9 GB | Llama 3.1 Community | [bartowski/Meta-Llama-3.1-8B-Instruct-GGUF](https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF) |

## Choosing a model

- **Low RAM (8 GB):** Start with TinyLlama 1.1B — fast, small, works on any machine.
- **Moderate RAM (12-16 GB):** Phi-3 Mini offers much better quality at 2.4 GB.
- **Plenty of RAM (16+ GB):** Mistral 7B or Llama 3.1 8B for best quality.

## Switching models

Use the model switcher to change the active model without editing files manually:

```bash
./scripts/switch-model.sh            # Interactive menu
./scripts/switch-model.sh --list     # List models and show which is active
./scripts/switch-model.sh Phi-3-mini-4k-instruct-Q4_K_M.gguf   # Switch directly
```

The script updates `DEFAULT_MODEL` in `.env` and restarts the llama-server container. Open WebUI reconnects automatically.

## Adding custom models

Any GGUF model compatible with llama.cpp will work:

1. Download a `.gguf` file from [Hugging Face](https://huggingface.co/models?sort=trending&search=gguf) or convert your own
2. Place the file in this `models/` directory
3. Switch to it: `./scripts/switch-model.sh <filename.gguf>`

Tips for finding models:
- Search Hugging Face for `GGUF` — look for repos by **bartowski**, **TheBloke**, or official model authors
- Choose **Q4_K_M** quantization for the best size/quality balance
- Larger models need more RAM: ~1 GB per billion parameters at Q4

## Quantization

All recommended models use **Q4_K_M** quantization — a 4-bit format that provides the best quality-to-size ratio. For higher quality at the cost of larger files, look for Q5_K_M or Q6_K variants on the same Hugging Face repos.

## License notes

- **Llama 3.1 8B:** Requires accepting Meta's community license on Hugging Face before downloading. Free for commercial and research use.
- All other models are fully open-source (Apache-2.0 or MIT).
