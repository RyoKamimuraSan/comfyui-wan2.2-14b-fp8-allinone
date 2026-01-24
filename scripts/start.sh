#!/bin/bash
set -e

echo "=========================================="
echo " ComfyUI All-in-One Starting..."
echo "=========================================="

# ストレージパスの自動検出（Paperspace: /storage, RunPod: /workspace）
echo ""
echo "[1/4] Setting up storage..."
STORAGE_PATH=""
if [ -d "/storage" ]; then
    STORAGE_PATH="/storage"
    echo "[STORAGE] Detected Paperspace storage: /storage"
elif [ -d "/workspace" ]; then
    STORAGE_PATH="/workspace"
    echo "[STORAGE] Detected RunPod storage: /workspace"
fi

if [ -n "$STORAGE_PATH" ]; then
    echo "[STORAGE] Setting up storage symlinks..."

    # $STORAGE_PATH/output ディレクトリを作成
    mkdir -p "$STORAGE_PATH/output"
    # /app/output -> $STORAGE_PATH/output
    if [ -d "/app/output" ] && [ ! -L "/app/output" ]; then
        rm -rf /app/output
    fi
    if [ ! -L "/app/output" ]; then
        ln -s "$STORAGE_PATH/output" /app/output
        echo "[STORAGE] /app/output -> $STORAGE_PATH/output"
    fi

    # $STORAGE_PATH/workflow ディレクトリを作成
    mkdir -p "$STORAGE_PATH/workflow"
    # /app/user/default/workflows -> $STORAGE_PATH/workflow
    mkdir -p /app/user/default
    if [ -d "/app/user/default/workflows" ] && [ ! -L "/app/user/default/workflows" ]; then
        rm -rf /app/user/default/workflows
    fi
    if [ ! -L "/app/user/default/workflows" ]; then
        ln -s "$STORAGE_PATH/workflow" /app/user/default/workflows
        echo "[STORAGE] /app/user/default/workflows -> $STORAGE_PATH/workflow"
    fi
else
    echo "[STORAGE] No external storage detected, using local directories"
fi

# カスタムノードのインストール
echo ""
echo "[2/4] Installing custom nodes..."
/usr/local/bin/install_custom_nodes.sh "$CUSTOM_NODE_URLS"

# RIFE モデルのダウンロード（Frame-Interpolation用）
mkdir -p /app/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife
/usr/local/bin/download_model.sh /app/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife \
    "https://github.com/styler00dollar/VSGAN-tensorrt-docker/releases/download/models/rife49.pth"

# Configure Civicomfy API key if set
if [ -n "$CIVITAI_API_KEY" ] && [ -d "/app/custom_nodes/Civicomfy/web/js" ]; then
    echo "[CONFIG] Setting Civitai API key for Civicomfy..."
    sed "s/__CIVITAI_API_KEY__/$CIVITAI_API_KEY/" /usr/local/bin/init-civicomfy-apikey.js \
        > /app/custom_nodes/Civicomfy/web/js/init-apikey.js
fi

# モデルのダウンロード
echo ""
echo "[3/4] Downloading models..."
/usr/local/bin/download_models.sh /app/models/checkpoints "$CHECKPOINT_URLS"
/usr/local/bin/download_models.sh /app/models/vae "$VAE_URLS"
/usr/local/bin/download_models.sh /app/models/loras "$LORA_URLS"
/usr/local/bin/download_models.sh /app/models/controlnet "$CONTROLNET_URLS"
/usr/local/bin/download_models.sh /app/models/upscale_models "$UPSCALE_URLS"
/usr/local/bin/download_models.sh /app/models/clip "$CLIP_URLS"
/usr/local/bin/download_models.sh /app/models/clip_vision "$CLIP_VISION_URLS"
/usr/local/bin/download_models.sh /app/models/unet "$UNET_URLS"
/usr/local/bin/download_models.sh /app/models/text_encoders "$TEXT_ENCODER_URLS"
/usr/local/bin/download_models.sh /app/models/diffusion_models "$DIFFUSION_MODEL_URLS"
/usr/local/bin/download_models.sh /app/models/ultralytics/bbox "$ULTRALYTICS_BBOX_URLS"

# サービス起動
echo ""
echo "[4/4] Starting services..."
echo "  - ComfyUI: http://0.0.0.0:6006"
echo "=========================================="

# supervisordでComfyUIを起動（自動再起動有効）
exec supervisord -c /etc/supervisor/supervisord.conf
