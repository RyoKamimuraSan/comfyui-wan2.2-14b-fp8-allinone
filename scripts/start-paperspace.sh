#!/bin/bash
set -e

echo "=========================================="
echo " ComfyUI All-in-One (Paperspace Mode)"
echo "=========================================="

# 1. /storage が存在する場合、シンボリックリンクを作成
echo ""
echo "[1/4] Setting up storage..."
if [ -d "/storage" ]; then
    echo "[STORAGE] Setting up storage symlinks..."

    # /storage/output ディレクトリを作成
    mkdir -p /storage/output
    # /app/output -> /storage/output
    if [ -d "/app/output" ] && [ ! -L "/app/output" ]; then
        rm -rf /app/output
    fi
    if [ ! -L "/app/output" ]; then
        ln -s /storage/output /app/output
        echo "[STORAGE] /app/output -> /storage/output"
    fi

    # /storage/workflow ディレクトリを作成
    mkdir -p /storage/workflow
    # /app/user/default/workflows -> /storage/workflow
    mkdir -p /app/user/default
    if [ -d "/app/user/default/workflows" ] && [ ! -L "/app/user/default/workflows" ]; then
        rm -rf /app/user/default/workflows
    fi
    if [ ! -L "/app/user/default/workflows" ]; then
        ln -s /storage/workflow /app/user/default/workflows
        echo "[STORAGE] /app/user/default/workflows -> /storage/workflow"
    fi
else
    echo "[STORAGE] /storage not mounted, using local directories"
fi

# 2. カスタムノードのインストール
echo ""
echo "[2/4] Installing custom nodes..."
/usr/local/bin/install_custom_nodes.sh "$CUSTOM_NODE_URLS"

# RIFE モデルのダウンロード（Frame-Interpolation用）
mkdir -p /app/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife
/usr/local/bin/download_model.sh /app/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife \
    "https://github.com/styler00dollar/VSGAN-tensorrt-docker/releases/download/models/rife49.pth"

# 3. モデルダウンロード（バックグラウンド）
echo ""
echo "[3/4] Downloading models..."
/usr/local/bin/download_models.sh /app/models/checkpoints "$CHECKPOINT_URLS" &
/usr/local/bin/download_models.sh /app/models/vae "$VAE_URLS" &
/usr/local/bin/download_models.sh /app/models/loras "$LORA_URLS" &
/usr/local/bin/download_models.sh /app/models/controlnet "$CONTROLNET_URLS" &
/usr/local/bin/download_models.sh /app/models/upscale_models "$UPSCALE_URLS" &
/usr/local/bin/download_models.sh /app/models/clip "$CLIP_URLS" &
/usr/local/bin/download_models.sh /app/models/unet "$UNET_URLS" &
/usr/local/bin/download_models.sh /app/models/text_encoders "$TEXT_ENCODER_URLS" &
/usr/local/bin/download_models.sh /app/models/diffusion_models "$DIFFUSION_MODEL_URLS" &
/usr/local/bin/download_models.sh /app/models/ultralytics/bbox "$ULTRALYTICS_BBOX_URLS" &

# 4. サービス起動
echo ""
echo "[4/4] Starting services..."
echo "  - JupyterLab: http://0.0.0.0:8888"
echo "  - ComfyUI: http://0.0.0.0:6006 (TensorBoard URL)"
echo "=========================================="

# supervisordで全サービスを起動（自動再起動有効）
exec supervisord -c /etc/supervisor/supervisord-paperspace.conf
