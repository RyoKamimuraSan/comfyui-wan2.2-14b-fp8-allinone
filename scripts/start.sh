#!/bin/bash
set -e

echo "=========================================="
echo " ComfyUI All-in-One Starting..."
echo "=========================================="

# カスタムノードのインストール
echo ""
echo "[1/3] Installing custom nodes..."
/usr/local/bin/install_custom_nodes.sh "$CUSTOM_NODE_URLS"

# RIFE モデルのダウンロード（Frame-Interpolation用）
mkdir -p /app/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife
/usr/local/bin/download_model.sh /app/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife \
    "https://github.com/styler00dollar/VSGAN-tensorrt-docker/releases/download/models/rife49.pth"

# モデルのダウンロード
echo ""
echo "[2/3] Downloading models..."
/usr/local/bin/download_models.sh /app/models/checkpoints "$CHECKPOINT_URLS"
/usr/local/bin/download_models.sh /app/models/vae "$VAE_URLS"
/usr/local/bin/download_models.sh /app/models/loras "$LORA_URLS"
/usr/local/bin/download_models.sh /app/models/controlnet "$CONTROLNET_URLS"
/usr/local/bin/download_models.sh /app/models/upscale_models "$UPSCALE_URLS"
/usr/local/bin/download_models.sh /app/models/clip "$CLIP_URLS"
/usr/local/bin/download_models.sh /app/models/unet "$UNET_URLS"
/usr/local/bin/download_models.sh /app/models/text_encoders "$TEXT_ENCODER_URLS"

# サービス起動
echo ""
echo "[3/3] Starting services..."
echo "  - ComfyUI: http://0.0.0.0:6006"
echo "=========================================="

# ComfyUIを起動
python main.py --listen 0.0.0.0 --port 6006 --fp8_e4m3fn-unet --fp8_e4m3fn-text-enc
