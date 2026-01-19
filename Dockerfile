# ============================================
# ComfyUI All-in-One Docker Image
# モデル・カスタムノードはコンテナ起動時にダウンロード
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
# 複数指定する場合はスペースまたは改行で区切る
#
# 書式:
#   URLのみ: https://example.com/model.safetensors
#   ファイル名指定: mymodel.safetensors::https://example.com/xxx
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
# ダウンロードヘルパースクリプト
# ============================================
RUN cat <<'EOF' > /usr/local/bin/download_model.sh
#!/bin/bash
set -e
# 引数: $1=出力ディレクトリ, $2=エントリ(URLまたはファイル名::URL)
entry="$2"
outdir="$1"

# 空の場合はスキップ
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
echo "  URL: $url"
echo "  Dir: $outdir"

aria2c -x5 --console-log-level=notice --summary-interval=10 \
    --content-disposition-default-utf8=true \
    -d "$outdir" -o "$filename" "$url"

if [ $? -eq 0 ]; then
    echo "[OK] Downloaded: $filename"
else
    echo "[ERROR] Failed to download: $filename"
    exit 1
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
# Custom Node インストールスクリプト
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
    echo "  URL: $repo_url"

    # タイムアウト付きでgit clone（5分）
    if timeout 300 git clone --depth 1 --progress "$repo_url" "$repo_name" 2>&1; then
        echo "[OK] Cloned: $repo_name"

        # requirements.txtがあればインストール
        if [ -f "$repo_name/requirements.txt" ]; then
            echo "[PIP] Installing requirements for $repo_name"
            if pip install -r "$repo_name/requirements.txt"; then
                echo "[OK] Requirements installed for $repo_name"
            else
                echo "[WARN] Failed to install requirements for $repo_name"
            fi
        fi
    else
        echo "[ERROR] Failed to clone $repo_name (timeout or network error)"
        echo "  Continuing with remaining nodes..."
    fi
done

echo "=== Custom node installation complete ==="
EOF
RUN chmod +x /usr/local/bin/install_custom_nodes.sh

# ============================================
# 起動スクリプト（モデル・カスタムノードをダウンロード）
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
echo "  - ComfyUI: http://0.0.0.0:8188"
echo "=========================================="

# Filebrowserをバックグラウンドで起動
filebrowser -r /app -a 0.0.0.0 -p 8080 &

# ComfyUIを起動
python main.py --listen 0.0.0.0 --port 8188
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
echo "  - ComfyUI: http://0.0.0.0:8188"
echo "  - JupyterLab: http://0.0.0.0:8888"
echo "=========================================="

# Filebrowserをバックグラウンドで起動
filebrowser -r /app -a 0.0.0.0 -p 8080 &

# ComfyUIをバックグラウンドで起動
cd /app && python main.py --listen 0.0.0.0 --port 8188 &

# JupyterLabをフォアグラウンドで起動（Paperspace UI用）
jupyter lab --allow-root --ip=0.0.0.0 --no-browser \
    --ServerApp.trust_xheaders=True \
    --ServerApp.disable_check_xsrf=False \
    --ServerApp.allow_remote_access=True \
    --ServerApp.allow_origin='*' \
    --ServerApp.allow_credentials=True
EOF
RUN chmod +x /app/start-paperspace.sh

# ============================================
# ポート公開
# ============================================
EXPOSE 8188 8080 8888

# ============================================
# 起動コマンド（デフォルトはスタンドアロン用）
# Paperspace Notebooks では /app/start-paperspace.sh を指定
# ============================================
CMD ["/app/start.sh"]
