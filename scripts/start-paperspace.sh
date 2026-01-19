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

# 2. /storage が存在する場合、output を永続化
echo ""
echo "[2/5] Setting up storage..."
if [ -d "/storage" ]; then
    echo "[STORAGE] Setting up output persistence..."
    if [ -d "/app/output" ] && [ ! -L "/app/output" ]; then
        rm -rf /app/output
    fi
    if [ ! -L "/app/output" ]; then
        ln -s /storage /app/output
        echo "[STORAGE] /app/output -> /storage (symlink created)"
    else
        echo "[STORAGE] /app/output -> /storage (symlink exists)"
    fi
else
    echo "[STORAGE] /storage not mounted, using local /app/output"
fi

# 3. カスタムノードのインストール
echo ""
echo "[3/5] Installing custom nodes..."
/usr/local/bin/install_custom_nodes.sh "$CUSTOM_NODE_URLS"

# 4. モデルダウンロード（バックグラウンド）
echo ""
echo "[4/5] Downloading models..."
/usr/local/bin/download_models.sh /app/models/checkpoints "$CHECKPOINT_URLS" &
/usr/local/bin/download_models.sh /app/models/vae "$VAE_URLS" &
/usr/local/bin/download_models.sh /app/models/loras "$LORA_URLS" &
/usr/local/bin/download_models.sh /app/models/upscale_models "$UPSCALE_URLS" &
/usr/local/bin/download_models.sh /app/models/text_encoders "$TEXT_ENCODER_URLS" &

# 5. サービス起動
echo ""
echo "[5/5] Starting services..."
echo "  - JupyterLab: http://0.0.0.0:8888 (already running)"
echo "  - Filebrowser: http://0.0.0.0:8080 (admin/admin)"
echo "  - ComfyUI: http://0.0.0.0:6006 (TensorBoard URL)"
echo "=========================================="

# Filebrowserをバックグラウンドで起動
filebrowser -r /app -a 0.0.0.0 -p 8080 &

# ComfyUIをバックグラウンドで起動（TensorBoardポート6006を使用）
cd /app && python main.py --listen 0.0.0.0 --port 6006 --fp8_e4m3fn-unet --fp8_e4m3fn-text-enc &

# 全バックグラウンドプロセスを待機
wait
