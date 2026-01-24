# ============================================
# ComfyUI All-in-One Docker Image
# モデルは起動時にダウンロード、カスタムノードはビルド時にインストール
# ============================================

# ============================================
# ベースイメージ（PyTorch公式イメージ）
# Python、PyTorch、CUDA、cuDNN全て含まれる
# ============================================
FROM pytorch/pytorch:2.9.1-cuda12.6-cudnn9-runtime

# 環境変数（ビルド時に必要なもののみ）
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

# ============================================
# システムパッケージのインストール
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    aria2 \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# ComfyUIのインストール
# ============================================
WORKDIR /app

# ComfyUIをクローン（--depth 1で高速化・サイズ削減）
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git . \
    && rm -rf .git

# ComfyUIの依存関係 + JupyterLab + supervisor をインストール
RUN pip install -r requirements.txt jupyterlab supervisor && \
    mkdir -p /var/log/supervisor && \
    find /opt/conda/lib/python*/site-packages -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

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
    /app/models/diffusion_models \
    /app/models/ultralytics/bbox \
    /app/input \
    /app/output \
    /app/custom_nodes

# ============================================
# カスタムノードをビルド時にインストール
# ============================================
WORKDIR /app/custom_nodes

# デフォルトのカスタムノードをクローン
RUN git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager && \
    git clone --depth 1 https://github.com/MoonGoblinDev/Civicomfy && \
    git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack && \
    cd ComfyUI-Impact-Pack && git submodule update --init --depth 1 && cd .. && \
    git clone --depth 1 https://github.com/1038lab/ComfyUI-RMBG && \
    git clone --depth 1 https://github.com/rgthree/rgthree-comfy && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes && \
    git clone --depth 1 https://github.com/Fannovel16/ComfyUI-Frame-Interpolation && \
    git clone --depth 1 https://github.com/pythongosssss/ComfyUI-Custom-Scripts && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-WanVideoWrapper && \
    rm -rf */.git

# カスタムノードの依存関係を一括インストール
RUN for dir in */; do \
      if [ -f "$dir/requirements.txt" ]; then \
        echo "Installing requirements for $dir" && \
        pip install -r "$dir/requirements.txt" || true; \
      fi; \
    done && \
    find /opt/conda/lib/python*/site-packages -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

WORKDIR /app

# ============================================
# スクリプトをコピー
# ============================================
COPY scripts/download_model.sh /usr/local/bin/
COPY scripts/download_models.sh /usr/local/bin/
COPY scripts/install_custom_nodes.sh /usr/local/bin/
COPY scripts/keepalive.sh /usr/local/bin/
COPY scripts/start.sh /app/
COPY scripts/start-paperspace.sh /app/

# supervisord設定ファイルをコピー
COPY scripts/supervisord.conf /etc/supervisor/supervisord.conf
COPY scripts/supervisord-paperspace.conf /etc/supervisor/supervisord-paperspace.conf

# 実行権限付与
RUN chmod +x /usr/local/bin/*.sh /app/*.sh

# ============================================
# 不要ファイルの削除（イメージサイズ最適化）
# ============================================
RUN rm -rf /opt/conda/lib/python*/site-packages/*/tests 2>/dev/null || true && \
    rm -rf /opt/conda/lib/python*/site-packages/*/test 2>/dev/null || true && \
    rm -rf /opt/conda/share/doc 2>/dev/null || true

# ============================================
# モデルダウンロードURL設定（環境変数で上書き可能）
# キャッシュ効率のためRUN命令の後に配置
# 書式: ファイル名::URL（スペースまたは改行区切り）
# ============================================
ENV CHECKPOINT_URLS=""
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
nsfw_wan_umt5-xxl_fp8_scaled.safetensors::https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors \
nsfw_wan_umt5-xxl_bf16.safetensors::https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_bf16.safetensors \
"
ENV DIFFUSION_MODEL_URLS="\
Wan2.2_Remix_NSFW_i2v_14b_high_lighting_fp8_e4m3fn_v2.1.safetensors::https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_fp8_e4m3fn_v2.1.safetensors \
Wan2.2_Remix_NSFW_i2v_14b_low_lighting_fp8_e4m3fn_v2.1.safetensors::https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_fp8_e4m3fn_v2.1.safetensors \
"
ENV ULTRALYTICS_BBOX_URLS=""

# 追加カスタムノード用（起動時にインストール）
ENV EXTRA_CUSTOM_NODE_URLS=""

# ============================================
# ポート公開
# ============================================
EXPOSE 6006 8888

# ============================================
# 起動コマンド（デフォルトはスタンドアロン用）
# Paperspace Notebooks では /app/start-paperspace.sh を指定
# ============================================
CMD ["/app/start.sh"]
