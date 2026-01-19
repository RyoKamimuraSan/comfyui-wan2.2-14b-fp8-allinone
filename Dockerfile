# ============================================
# ComfyUI All-in-One Docker Image
# モデルは起動時にダウンロード、カスタムノードも起動時にインストール
# ============================================

# ============================================
# ベースイメージ（PyTorch公式イメージ）
# Python、PyTorch、CUDA、cuDNN全て含まれる
# ============================================
FROM pytorch/pytorch:2.9.1-cuda12.6-cudnn9-runtime

# 環境変数
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

# ============================================
# モデルダウンロードURL設定（環境変数で上書き可能）
# 書式: ファイル名::URL（スペースまたは改行区切り）
# ============================================
ENV CHECKPOINT_URLS="\
Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors::https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors \
Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors::https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors \
"
ENV VAE_URLS="\
wan_2.1_vae.safetensors::https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors \
"
ENV LORA_URLS=""
ENV CONTROLNET_URLS=""
ENV UPSCALE_URLS="\
4x-UltraSharp.pth::https://huggingface.co/lokCX/4x-Ultrasharp/resolve/main/4x-UltraSharp.pth \
"
ENV CLIP_URLS=""
ENV UNET_URLS=""
ENV TEXT_ENCODER_URLS="\
nsfw_wan_umt5-xxl_bf16.safetensors::https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_bf16.safetensors \
"

# ============================================
# Custom Node インストール設定（環境変数で上書き可能）
# ============================================
ENV CUSTOM_NODE_URLS="\
https://github.com/Comfy-Org/ComfyUI-Manager \
https://github.com/MoonGoblinDev/Civicomfy \
https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite \
https://github.com/ltdrdata/ComfyUI-Impact-Pack \
https://github.com/1038lab/ComfyUI-RMBG \
https://github.com/rgthree/rgthree-comfy \
https://github.com/kijai/ComfyUI-KJNodes \
https://github.com/Fannovel16/ComfyUI-Frame-Interpolation \
https://github.com/pythongosssss/ComfyUI-Custom-Scripts \
"

# ============================================
# システムパッケージのインストール
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget \
    curl \
    aria2 \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Filebrowserのインストール
# ============================================
RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# ============================================
# ComfyUIのインストール
# ============================================
WORKDIR /app

# ComfyUIをクローン
RUN git clone https://github.com/comfyanonymous/ComfyUI.git . \
    && rm -rf .git

# ComfyUIの依存関係をインストール
RUN pip install -r requirements.txt

# ============================================
# JupyterLab のインストール（Paperspace Notebooks用）
# ============================================
RUN pip install jupyterlab

# ============================================
# ディレクトリ構造の作成
# ============================================
RUN mkdir -p \
    /app/models/checkpoints \
    /app/models/vae \
    /app/models/loras \
    /app/models/controlnet \
    /app/models/upscale_models \
    /app/models/clip \
    /app/models/unet \
    /app/models/text_encoders \
    /app/input \
    /app/output \
    /app/custom_nodes

# ============================================
# ダウンロードヘルパースクリプト（aria2c -x5）
# ============================================
RUN cat <<'EOF' > /usr/local/bin/download_model.sh
#!/bin/bash
# 引数: $1=出力ディレクトリ, $2=エントリ(ファイル名::URL または URLのみ)
entry="$2"
outdir="$1"

[ -z "$entry" ] && exit 0

if [[ "$entry" == *"::"* ]]; then
    # ファイル名::URL 形式
    filename="${entry%%::*}"
    url="${entry#*::}"
else
    # URLのみ形式
    filename=$(basename "$entry")
    url="$entry"
fi

filepath="$outdir/$filename"

# 既にダウンロード済みならスキップ
if [ -f "$filepath" ]; then
    echo "[SKIP] Already exists: $filename"
    exit 0
fi

echo "[DOWNLOAD] $filename"
if aria2c -x5 \
    --connect-timeout=60 \
    --timeout=600 \
    --max-tries=3 \
    --retry-wait=10 \
    -d "$outdir" -o "$filename" "$url"; then
    echo "[OK] Downloaded: $filename"
else
    echo "[WARN] Failed to download: $filename"
fi
EOF
RUN chmod +x /usr/local/bin/download_model.sh

# ダウンロード実行スクリプト（スペース・改行両対応）
RUN cat <<'EOF' > /usr/local/bin/download_models.sh
#!/bin/bash
# 引数: $1=出力ディレクトリ, $2=URL一覧（スペースまたは改行区切り）
outdir="$1"
urls="$2"

[ -z "$urls" ] && exit 0

echo "=== Downloading models to $outdir ==="

echo "$urls" | tr ' ' '\n' | while read -r entry; do
    # 空行・空白のみをスキップ
    entry=$(echo "$entry" | xargs)
    [ -z "$entry" ] && continue
    /usr/local/bin/download_model.sh "$outdir" "$entry"
done
EOF
RUN chmod +x /usr/local/bin/download_models.sh

# ============================================
# Custom Node インストールスクリプト（タイムアウト時は削除してスキップ）
# ============================================
RUN cat <<'EOF' > /usr/local/bin/install_custom_nodes.sh
#!/bin/bash
# 引数: $1=Custom Node URL一覧（スペースまたは改行区切り）
urls="$1"

[ -z "$urls" ] && exit 0

cd /app/custom_nodes

echo "=== Installing custom nodes ==="

echo "$urls" | tr ' ' '\n' | while read -r repo_url; do
    # 空行・空白のみをスキップ
    repo_url=$(echo "$repo_url" | xargs)
    [ -z "$repo_url" ] && continue

    # リポジトリ名を取得
    repo_name=$(basename "$repo_url" .git)

    # 既にインストール済みならスキップ
    if [ -d "$repo_name" ]; then
        echo "[SKIP] Already installed: $repo_name"
        continue
    fi

    echo "[INSTALL] $repo_name"

    # git clone with timeout (5min)
    if ! timeout 300 git clone --depth 1 "$repo_url" "$repo_name" 2>&1; then
        echo "[ERROR] Failed to clone $repo_name, removing and skipping..."
        rm -rf "$repo_name"
        continue
    fi

    echo "[OK] Cloned: $repo_name"

    # pip install with timeout (10min)
    if [ -f "$repo_name/requirements.txt" ]; then
        echo "[PIP] Installing requirements for $repo_name"
        if ! timeout 600 pip install -r "$repo_name/requirements.txt" 2>&1; then
            echo "[ERROR] Failed to install requirements for $repo_name, removing and skipping..."
            rm -rf "$repo_name"
            continue
        fi
        echo "[OK] Requirements installed for $repo_name"
    fi
done

echo "=== Custom node installation complete ==="
EOF
RUN chmod +x /usr/local/bin/install_custom_nodes.sh

# ============================================
# 起動スクリプト（スタンドアロン用）
# ============================================
RUN cat <<'EOF' > /app/start.sh
#!/bin/bash
set -e

echo "=========================================="
echo " ComfyUI All-in-One Starting..."
echo "=========================================="

# カスタムノードのインストール
echo ""
echo "[1/3] Installing custom nodes..."
/usr/local/bin/install_custom_nodes.sh "$CUSTOM_NODE_URLS"

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
echo "  - Filebrowser: http://0.0.0.0:8080 (admin/admin)"
echo "  - ComfyUI: http://0.0.0.0:6006"
echo "=========================================="

# Filebrowserをバックグラウンドで起動
filebrowser -r /app -a 0.0.0.0 -p 8080 &

# ComfyUIを起動
python main.py --listen 0.0.0.0 --port 6006
EOF
RUN chmod +x /app/start.sh

# ============================================
# Paperspace Notebooks 用起動スクリプト
# ============================================
RUN cat <<'EOF' > /app/start-paperspace.sh
#!/bin/bash
set -e

echo "=========================================="
echo " ComfyUI All-in-One (Paperspace Mode)"
echo "=========================================="

# 1. JupyterLabを最初にバックグラウンドで起動（Paperspace UIが「Running」表示）
echo ""
echo "[1/4] Starting JupyterLab..."
PIP_DISABLE_PIP_VERSION_CHECK=1 jupyter lab --allow-root --ip=0.0.0.0 --no-browser \
    --ServerApp.trust_xheaders=True \
    --ServerApp.disable_check_xsrf=False \
    --ServerApp.allow_remote_access=True \
    --ServerApp.allow_origin='*' \
    --ServerApp.allow_credentials=True &

# 2. カスタムノードのインストール
echo ""
echo "[2/4] Installing custom nodes..."
/usr/local/bin/install_custom_nodes.sh "$CUSTOM_NODE_URLS"

# 3. モデルダウンロード（バックグラウンド）
echo ""
echo "[3/4] Downloading models..."
/usr/local/bin/download_models.sh /app/models/checkpoints "$CHECKPOINT_URLS" &
/usr/local/bin/download_models.sh /app/models/vae "$VAE_URLS" &
/usr/local/bin/download_models.sh /app/models/loras "$LORA_URLS" &
/usr/local/bin/download_models.sh /app/models/upscale_models "$UPSCALE_URLS" &
/usr/local/bin/download_models.sh /app/models/text_encoders "$TEXT_ENCODER_URLS" &

# 4. サービス起動
echo ""
echo "[4/4] Starting services..."
echo "  - JupyterLab: http://0.0.0.0:8888 (already running)"
echo "  - Filebrowser: http://0.0.0.0:8080 (admin/admin)"
echo "  - ComfyUI: http://0.0.0.0:6006 (TensorBoard URL)"
echo "=========================================="

# Filebrowserをバックグラウンドで起動
filebrowser -r /app -a 0.0.0.0 -p 8080 &

# ComfyUIをバックグラウンドで起動（TensorBoardポート6006を使用）
cd /app && python main.py --listen 0.0.0.0 --port 6006 &

# 全バックグラウンドプロセスを待機
wait
EOF
RUN chmod +x /app/start-paperspace.sh

# ============================================
# ポート公開
# ============================================
EXPOSE 6006 8080 8888

# ============================================
# 起動コマンド（デフォルトはスタンドアロン用）
# Paperspace Notebooks では /app/start-paperspace.sh を指定
# ============================================
CMD ["/app/start.sh"]
