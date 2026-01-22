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
https://github.com/kijai/ComfyUI-WanVideoWrapper \
"

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

# ComfyUIをクローン
RUN git clone https://github.com/comfyanonymous/ComfyUI.git . \
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
# スクリプトをコピー
# ============================================
COPY scripts/download_model.sh /usr/local/bin/
COPY scripts/download_models.sh /usr/local/bin/
COPY scripts/install_custom_nodes.sh /usr/local/bin/
COPY scripts/start.sh /app/
COPY scripts/start-paperspace.sh /app/

# supervisord設定ファイルをコピー
COPY scripts/supervisord.conf /etc/supervisor/supervisord.conf
COPY scripts/supervisord-paperspace.conf /etc/supervisor/supervisord-paperspace.conf

# 実行権限付与
RUN chmod +x /usr/local/bin/*.sh /app/*.sh

# ============================================
# ポート公開
# ============================================
EXPOSE 6006 8888

# ============================================
# 起動コマンド（デフォルトはスタンドアロン用）
# Paperspace Notebooks では /app/start-paperspace.sh を指定
# ============================================
CMD ["/app/start.sh"]
