# ============================================
# ComfyUI All-in-One Docker Image
# モデルはGCSからマウント、カスタムノードは起動時にダウンロード
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
    gnupg \
    lsb-release \
    fuse \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# gcsfuseのインストール（GCSマウント用）
# ============================================
RUN echo "deb https://packages.cloud.google.com/apt gcsfuse-$(lsb_release -c -s) main" \
    > /etc/apt/sources.list.d/gcsfuse.list \
    && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && apt-get update \
    && apt-get install -y gcsfuse \
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

# タイムアウトとリトライを設定、並列接続を1に減らす
if aria2c -x1 \
    --connect-timeout=60 \
    --timeout=600 \
    --max-tries=3 \
    --retry-wait=10 \
    --console-log-level=notice \
    --summary-interval=30 \
    --content-disposition-default-utf8=true \
    -d "$outdir" -o "$filename" "$url"; then
    echo "[OK] Downloaded: $filename"
else
    echo "[ERROR] Failed to download: $filename"
    echo "  Continuing with remaining models..."
    exit 0
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
# GCSマウント用ディレクトリ作成
# ============================================
RUN mkdir -p /mnt/gcs

# ============================================
# GCSマウントスクリプト
# ============================================
RUN cat <<'EOF' > /usr/local/bin/mount_gcs.sh
#!/bin/bash
# GCSバケットをマウントしてモデルディレクトリにシンボリックリンクを作成

# 環境変数チェック
if [ -z "$GCS_BUCKET" ]; then
    echo "[GCS] GCS_BUCKET not set, skipping GCS mount"
    exit 0
fi

# Base64エンコードされた認証情報をデコード
if [ -n "$GCS_KEY_BASE64" ]; then
    echo "[GCS] Decoding service account key..."
    echo "$GCS_KEY_BASE64" | base64 -d > /tmp/gcs-key.json
    export GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcs-key.json
fi

echo "[GCS] Mounting bucket: $GCS_BUCKET"

# キャッシュディレクトリ作成
mkdir -p /tmp/gcsfuse-cache

# gcsfuseでマウント（キャッシュ有効）
gcsfuse \
    --file-cache-max-size-mb=-1 \
    --file-cache-cache-file-for-range-read \
    --stat-cache-ttl=1h \
    --type-cache-ttl=1h \
    --implicit-dirs \
    --foreground=false \
    "$GCS_BUCKET" /mnt/gcs

if [ $? -ne 0 ]; then
    echo "[GCS] ERROR: Failed to mount GCS bucket"
    exit 1
fi

echo "[GCS] Successfully mounted $GCS_BUCKET to /mnt/gcs"

# 既存のmodelsディレクトリを削除してシンボリックリンクを作成
echo "[GCS] Creating symlinks to model directories..."
rm -rf /app/models
ln -sf /mnt/gcs /app/models

echo "[GCS] Symlink created: /app/models -> /mnt/gcs"
EOF
RUN chmod +x /usr/local/bin/mount_gcs.sh

# ============================================
# モデルプリフェッチスクリプト
# ============================================
RUN cat <<'EOF' > /usr/local/bin/prefetch_models.sh
#!/bin/bash
# バックグラウンドで全モデルファイルを読み込んでキャッシュ作成

if [ ! -d "/mnt/gcs" ] || [ -z "$(ls -A /mnt/gcs 2>/dev/null)" ]; then
    echo "[PREFETCH] GCS not mounted or empty, skipping prefetch"
    exit 0
fi

echo "[PREFETCH] Starting model cache prefetch..."

find /mnt/gcs -type f \( -name "*.safetensors" -o -name "*.pth" -o -name "*.ckpt" -o -name "*.bin" \) 2>/dev/null | while read -r file; do
    filename=$(basename "$file")
    echo "[PREFETCH] Caching: $filename"
    cat "$file" > /dev/null 2>&1
done

echo "[PREFETCH] Complete!"
EOF
RUN chmod +x /usr/local/bin/prefetch_models.sh

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
# Paperspace Notebooks 用起動スクリプト（GCSマウント対応）
# ============================================
RUN cat <<'EOF' > /app/start-paperspace.sh
#!/bin/bash
set -e

echo "=========================================="
echo " ComfyUI All-in-One (Paperspace Mode)"
echo "=========================================="

# 1. JupyterLabを先にバックグラウンドで起動（Paperspace UIが「Running」表示）
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

# 3. GCSマウント
echo ""
echo "[3/4] Mounting GCS bucket..."
/usr/local/bin/mount_gcs.sh

# プリフェッチをバックグラウンドで開始
/usr/local/bin/prefetch_models.sh &

# 4. サービス起動
echo ""
echo "[4/4] Starting services..."
echo "  - JupyterLab: http://0.0.0.0:8888 (already running)"
echo "  - Filebrowser: http://0.0.0.0:8080 (admin/admin)"
echo "  - ComfyUI: http://0.0.0.0:8188"
echo "=========================================="

# Filebrowserをバックグラウンドで起動
filebrowser -r /app -a 0.0.0.0 -p 8080 &

# ComfyUIをバックグラウンドで起動
cd /app && python main.py --listen 0.0.0.0 --port 8188 &

# 全バックグラウンドプロセスを待機
wait
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
