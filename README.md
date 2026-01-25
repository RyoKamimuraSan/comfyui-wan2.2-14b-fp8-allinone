# ComfyUI All-in-One Docker Image

A Docker image for easy ComfyUI deployment with automatic model downloading and JupyterLab integration.

## Features

- **Auto Model Download** - Models download automatically at startup via environment variables
- **JupyterLab Included** - For notebook workflows and file management
- **Pre-installed Custom Nodes** - Popular nodes ready to use out of the box
- **PyTorch 2.9.1 + CUDA 12.6** - Latest deep learning stack

## Tested Platforms

- Paperspace Notebooks
- RunPod
- Local Docker

**Docker Hub**: [ryokamimurasan](https://hub.docker.com/u/ryokamimurasan)

---

## Paperspace Notebooks

### Setup

| Setting | Value |
|---------|-------|
| Container Image | `ryokamimurasan/comfyui-wan22-14b-fp8-paperspace-nb` |
| Command | `/app/start-paperspace.sh` |

### Accessing Services

| Service | Port | URL Format |
|---------|------|------------|
| ComfyUI | 6006 | `https://tensorboard-{notebook-id}.paperspacegradient.com` |
| JupyterLab | 8888 | Default Paperspace URL |

**Example:**
- JupyterLab: `https://abc123.xyz456.paperspacegradient.com`
- ComfyUI: `https://tensorboard-abc123.xyz456.paperspacegradient.com`

### Keepalive Feature

Automatically enabled in Paperspace mode. Sends a beacon every 15 minutes to prevent idle shutdown.

### Storage Persistence

The following directories are automatically linked to `/storage` for persistence:

| Local Path | Linked To |
|------------|-----------|
| `/app/output` | `/storage/output` |
| `/app/user/default/workflows` | `/storage/workflow` |

---

## RunPod

Tested and confirmed working on RunPod. Uses `/workspace` for storage persistence with the same features as Paperspace.

---

## Local Docker

### Basic Usage

```bash
docker run --gpus all -p 6006:6006 -p 8888:8888 \
  ryokamimurasan/comfyui-wan22-14b-fp8-paperspace-nb
```

### With Volume Mounts (Recommended)

```bash
docker run --gpus all -p 6006:6006 -p 8888:8888 \
  -v $(pwd)/models:/app/models \
  -v $(pwd)/output:/app/output \
  ryokamimurasan/comfyui-wan22-14b-fp8-paperspace-nb
```

### Access

| Service | URL |
|---------|-----|
| ComfyUI | `http://localhost:6006` |
| JupyterLab | `http://localhost:8888` |

---

## Paperspace vs Local Docker

| Aspect | Paperspace | Local Docker |
|--------|------------|--------------|
| Command | `/app/start-paperspace.sh` | (default entrypoint) |
| Keepalive | Auto-enabled | Not needed |
| Storage | `/storage` auto-linked | Use `-v` volume mounts |
| Access | Via Paperspace proxy URLs | `localhost:port` |

---

## Available Images

| Image | Use Case | Default Models |
|-------|----------|----------------|
| `ryokamimurasan/comfyui-wan22-14b-fp8-paperspace-nb` | Wan2.2 14B video generation | Wan2.2 Remix NSFW i2v 14b, wan 2.1 VAE, 4x-UltraSharp |
| `ryokamimurasan/comfyui-qwen-image-edit-2511-paperspace-nb` | Image editing with Qwen | Qwen Image Edit fp8, 2dn_animeV3, qwen_2.5_vl_7b |
| `ryokamimurasan/comfyui-wan22-smooth-mix-v2-paperspace-nb` | Wan2.2 smooth-mix video | smoothMixWan22 i2v models, LightX2V LoRA |

### comfyui-wan22-14b-fp8-paperspace-nb (Default)

Optimized for Wan2.2 14B video generation:
- Wan2.2 Remix NSFW i2v 14b (high/low lighting)
- wan 2.1 VAE
- 4x-UltraSharp upscaler
- nsfw_wan_umt5-xxl_fp8_scaled text encoder

### comfyui-qwen-image-edit-2511-paperspace-nb

Optimized for Qwen-based image editing:
- qwen_image_edit_2511_fp8 lightning 8-steps
- 2dn_animeV3 checkpoint
- qwen_2.5_vl_7b_fp8 text encoder
- Ultralytics BBOX models for segmentation

**Note:** Requires `CIVITAI_API_KEY` for some models.

### comfyui-wan22-smooth-mix-v2-paperspace-nb

Optimized for smooth-mix video generation:
- smoothMixWan22 14B i2v (high/low versions)
- LightX2V step distill LoRA
- CLIP Vision model
- Both fp8 and bf16 text encoders

---

## Configuration

### Environment Variables

| Variable | Description | Format |
|----------|-------------|--------|
| `CIVITAI_API_KEY` | Civitai API key for model downloads and Civicomfy | API key string |
| `CHECKPOINT_URLS` | Checkpoint models | `filename::URL` (space-separated) |
| `VAE_URLS` | VAE models | `filename::URL` |
| `LORA_URLS` | LoRA models | `filename::URL` |
| `CONTROLNET_URLS` | ControlNet models | `filename::URL` |
| `UPSCALE_URLS` | Upscale models | `filename::URL` |
| `CLIP_URLS` | CLIP models | `filename::URL` |
| `CLIP_VISION_URLS` | CLIP Vision models | `filename::URL` |
| `TEXT_ENCODER_URLS` | Text encoders | `filename::URL` |
| `DIFFUSION_MODEL_URLS` | Diffusion models | `filename::URL` |
| `UNET_URLS` | UNet models | `filename::URL` |
| `ULTRALYTICS_BBOX_URLS` | Ultralytics BBOX models | `filename::URL` |
| `EXTRA_CUSTOM_NODE_URLS` | Additional custom nodes | Git URLs (space-separated) |

### Example

```bash
docker run --gpus all -p 6006:6006 \
  -e CIVITAI_API_KEY=your_api_key \
  -e LORA_URLS="style.safetensors::https://example.com/style.safetensors" \
  ryokamimurasan/comfyui-wan22-14b-fp8-paperspace-nb
```

### Civitai API Key

Setting `CIVITAI_API_KEY` enables:
1. **Model Downloads** - Authentication for downloading from Civitai URLs
2. **Civicomfy Integration** - API key is automatically injected into Civicomfy settings

---

## Pre-installed Custom Nodes

| Node | Repository |
|------|------------|
| ComfyUI-Manager | [ltdrdata/ComfyUI-Manager](https://github.com/ltdrdata/ComfyUI-Manager) |
| Civicomfy | [Civitai/civitai_comfy_nodes](https://github.com/Civitai/civitai_comfy_nodes) |
| ComfyUI-VideoHelperSuite | [Kosinkadink/ComfyUI-VideoHelperSuite](https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite) |
| ComfyUI-Impact-Pack | [ltdrdata/ComfyUI-Impact-Pack](https://github.com/ltdrdata/ComfyUI-Impact-Pack) |
| ComfyUI-RMBG | [ssitu/ComfyUI-RMBG](https://github.com/ssitu/ComfyUI-RMBG) |
| rgthree-comfy | [rgthree/rgthree-comfy](https://github.com/rgthree/rgthree-comfy) |
| ComfyUI-KJNodes | [kijai/ComfyUI-KJNodes](https://github.com/kijai/ComfyUI-KJNodes) |
| ComfyUI-Frame-Interpolation | [Fannovel16/ComfyUI-Frame-Interpolation](https://github.com/Fannovel16/ComfyUI-Frame-Interpolation) |
| ComfyUI-Custom-Scripts | [pythongosssss/ComfyUI-Custom-Scripts](https://github.com/pythongosssss/ComfyUI-Custom-Scripts) |
| ComfyUI-WanVideoWrapper* | [kijai/ComfyUI-WanVideoWrapper](https://github.com/kijai/ComfyUI-WanVideoWrapper) |

*ComfyUI-WanVideoWrapper is included in `comfyui-wan22-14b-fp8-paperspace-nb` and `comfyui-wan22-smooth-mix-v2-paperspace-nb` images only.

---

## Building from Source

```bash
# Main image
docker build -t comfyui-allinone .

# Qwen Image Edit image
docker build -f Dockerfile.qwen-image-edit-2511 -t comfyui-qwen-image-edit-2511 .

# Wan22 Smooth Mix image
docker build -f Dockerfile.wan22-smooth-mix -t comfyui-wan22-smooth-mix .
```

---

## License

MIT
