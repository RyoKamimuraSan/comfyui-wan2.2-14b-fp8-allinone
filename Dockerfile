# ============================================
# ComfyUI All-in-One Docker Image
# ============================================

# ============================================
# モデルダウンロードURL設定（ここを編集）
# 複数指定する場合はスペースで区切る
#
# 書式:
#   URLのみ: https://example.com/model.safetensors
#   ファイル名指定: mymodel.safetensors::https://example.com/xxx
# ============================================
ARG CHECKPOINT_URLS=""
# 例: ARG CHECKPOINT_URLS="model.safetensors::https://civitai.com/api/download/xxx https://huggingface.co/xxx/model.safetensors"

ARG VAE_URLS=""
# 例: ARG VAE_URLS="vae.safetensors::https://example.com/xxx"

ARG LORA_URLS=""
# 例: ARG LORA_URLS="lora1.safetensors::https://example.com/xxx lora2.safetensors::https://example.com/yyy"

ARG CONTROLNET_URLS=""
ARG UPSCALE_URLS=""
ARG CLIP_URLS=""
ARG UNET_URLS=""

# ============================================
# ベースイメージ
# ============================================
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

# 環境変数
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

# ARGを再宣言（FROM後に必要）
ARG CHECKPOINT_URLS
ARG VAE_URLS
ARG LORA_URLS
ARG CONTROLNET_URLS
ARG UPSCALE_URLS
ARG CLIP_URLS
ARG UNET_URLS

# ============================================
# システムパッケージのインストール
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    python3-pip \
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

# Python3.12をデフォルトに設定
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1

# pipのアップグレード
RUN python -m pip install --upgrade pip setuptools wheel

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

# PyTorchのインストール（CUDA 12.4対応）
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# ComfyUIの依存関係をインストール
RUN pip install -r requirements.txt

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
    /app/input \
    /app/output \
    /app/custom_nodes

# ============================================
# ダウンロードヘルパースクリプト
# ============================================
RUN echo '#!/bin/bash\n\
# 引数: $1=出力ディレクトリ, $2=エントリ(URLまたはファイル名::URL)\n\
entry="$2"\n\
outdir="$1"\n\
\n\
if [[ "$entry" == *"::"* ]]; then\n\
    # ファイル名::URL 形式\n\
    filename="${entry%%::*}"\n\
    url="${entry#*::}"\n\
    aria2c -x5 --content-disposition-default-utf8=true -d "$outdir" -o "$filename" "$url"\n\
else\n\
    # URLのみ形式（Content-Dispositionからファイル名を取得）\n\
    aria2c -x5 --content-disposition-default-utf8=true -d "$outdir" "$entry"\n\
fi\n\
' > /usr/local/bin/download_model.sh && chmod +x /usr/local/bin/download_model.sh

# ============================================
# モデルのダウンロード（aria2c -x5 で高速化）
# ============================================
RUN if [ -n "$CHECKPOINT_URLS" ]; then \
    for entry in $CHECKPOINT_URLS; do \
        /usr/local/bin/download_model.sh /app/models/checkpoints "$entry"; \
    done; \
    fi

RUN if [ -n "$VAE_URLS" ]; then \
    for entry in $VAE_URLS; do \
        /usr/local/bin/download_model.sh /app/models/vae "$entry"; \
    done; \
    fi

RUN if [ -n "$LORA_URLS" ]; then \
    for entry in $LORA_URLS; do \
        /usr/local/bin/download_model.sh /app/models/loras "$entry"; \
    done; \
    fi

RUN if [ -n "$CONTROLNET_URLS" ]; then \
    for entry in $CONTROLNET_URLS; do \
        /usr/local/bin/download_model.sh /app/models/controlnet "$entry"; \
    done; \
    fi

RUN if [ -n "$UPSCALE_URLS" ]; then \
    for entry in $UPSCALE_URLS; do \
        /usr/local/bin/download_model.sh /app/models/upscale_models "$entry"; \
    done; \
    fi

RUN if [ -n "$CLIP_URLS" ]; then \
    for entry in $CLIP_URLS; do \
        /usr/local/bin/download_model.sh /app/models/clip "$entry"; \
    done; \
    fi

RUN if [ -n "$UNET_URLS" ]; then \
    for entry in $UNET_URLS; do \
        /usr/local/bin/download_model.sh /app/models/unet "$entry"; \
    done; \
    fi

# ============================================
# 起動スクリプト
# ============================================
RUN echo '#!/bin/bash\n\
# Filebrowserをバックグラウンドで起動\n\
filebrowser -r /app -a 0.0.0.0 -p 8080 &\n\
\n\
# ComfyUIを起動\n\
python main.py --listen 0.0.0.0 --port 8188\n\
' > /app/start.sh && chmod +x /app/start.sh

# ============================================
# ポート公開
# ============================================
EXPOSE 8188 8080

# ============================================
# 起動コマンド
# ============================================
CMD ["/app/start.sh"]
