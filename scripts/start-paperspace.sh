#!/bin/bash
set -e

echo "=========================================="
echo " ComfyUI All-in-One (Paperspace Mode)"
echo "=========================================="

# 1. JupyterLabを最初にバックグラウンドで起動（Paperspace UIが「Running」表示）
echo ""
echo "[1/5] Starting JupyterLab..."
PIP_DISABLE_PIP_VERSION_CHECK=1 jupyter lab --allow-root --ip=0.0.0.0 --no-browser \
    --notebook-dir=/app \
    --ServerApp.trust_xheaders=True \
    --ServerApp.disable_check_xsrf=False \
    --ServerApp.allow_remote_access=True \
    --ServerApp.allow_origin='*' \
    --ServerApp.allow_credentials=True &

# 2. /storage が存在する場合、シンボリックリンクを作成
echo ""
echo "[2/5] Setting up storage..."
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

# 3. カスタムノードのインストール
echo ""
echo "[3/5] Installing custom nodes..."
/usr/local/bin/install_custom_nodes.sh "$CUSTOM_NODE_URLS"

# RIFE モデルのダウンロード（Frame-Interpolation用）
mkdir -p /app/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife
/usr/local/bin/download_model.sh /app/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife \
    "https://github.com/styler00dollar/VSGAN-tensorrt-docker/releases/download/models/rife49.pth"

# 4. モデルダウンロード（バックグラウンド）
echo ""
echo "[4/5] Downloading models..."
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

# 5. サービス起動
echo ""
echo "[5/5] Starting services..."
echo "  - JupyterLab: http://0.0.0.0:8888 (already running)"
echo "  - ComfyUI: http://0.0.0.0:6006 (TensorBoard URL)"
echo "=========================================="

# ComfyUIをバックグラウンドで起動（TensorBoardポート6006を使用）
cd /app && python main.py --listen 0.0.0.0 --port 6006 --fp8_e4m3fn-unet --fp8_e4m3fn-text-enc &

# 全バックグラウンドプロセスを待機
wait
