# ============================================
# ComfyUI All-in-One Docker Image
# ============================================

# ============================================
# モデルダウンロードURL設定（ここを編集）
# 複数指定する場合はスペースまたは改行で区切る
#
# 書式:
#   URLのみ: https://example.com/model.safetensors
#   ファイル名指定: mymodel.safetensors::https://example.com/xxx
#
# 例（改行区切り）:
#   ARG CHECKPOINT_URLS="\
#   model1.safetensors::https://example.com/xxx \
#   model2.safetensors::https://example.com/yyy \
#   "
# ============================================
ARG CHECKPOINT_URLS="\
Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors::https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors \
Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors::https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors \
"
ARG VAE_URLS="\
split_files/vae/wan_2.1_vae.safetensors::https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors \
"
ARG LORA_URLS=""
ARG CONTROLNET_URLS=""
ARG UPSCALE_URLS="\
4x-UltraSharp.pth::https://huggingface.co/lokCX/4x-Ultrasharp/resolve/main/4x-UltraSharp.pth \
"
ARG CLIP_URLS=""
ARG UNET_URLS=""
ARG TEXT_ENCODER_URLS="\
nsfw_wan_umt5-xxl_bf16.safetensors::https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_bf16.safetensors \
"

# ============================================
# Custom Node インストール設定
# GitHubリポジトリURLを指定（スペースまたは改行区切り）
#
# 例:
#   ARG CUSTOM_NODE_URLS="\
#   https://github.com/ltdrdata/ComfyUI-Manager \
#   https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite \
#   "
# ============================================
ARG CUSTOM_NODE_URLS="\
https://github.com/Comfy-Org/ComfyUI-Manager \
https://github.com/MoonGoblinDev/Civicomfy \
https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite \
https://github.com/ltdrdata/ComfyUI-Impact-Pack \
https://github.com/1038lab/ComfyUI-RMBG \
https://github.com/rgthree/rgthree-comfy \
https://github.com/kijai/ComfyUI-KJNodes \
"

# ============================================
# ベースイメージ（PyTorch公式イメージ）
# Python、PyTorch、CUDA、cuDNN全て含まれる
# ============================================
FROM pytorch/pytorch:2.9.1-cuda12.6-cudnn9-runtime

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
ARG TEXT_ENCODER_URLS
ARG CUSTOM_NODE_URLS

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
    aria2c -x5 --content-disposition-default-utf8=true -d "$outdir" -o "$filename" "$url"
else
    # URLのみ形式（Content-Dispositionからファイル名を取得）
    aria2c -x5 --content-disposition-default-utf8=true -d "$outdir" "$entry"
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

echo "$urls" | tr ' ' '\n' | while read -r entry; do
    # 空行・空白のみをスキップ
    entry=$(echo "$entry" | xargs)
    [ -z "$entry" ] && continue
    /usr/local/bin/download_model.sh "$outdir" "$entry"
done
EOF
RUN chmod +x /usr/local/bin/download_models.sh

# ============================================
# モデルのダウンロード（aria2c -x5 で高速化）
# ============================================
RUN /usr/local/bin/download_models.sh /app/models/checkpoints "$CHECKPOINT_URLS"
RUN /usr/local/bin/download_models.sh /app/models/vae "$VAE_URLS"
RUN /usr/local/bin/download_models.sh /app/models/loras "$LORA_URLS"
RUN /usr/local/bin/download_models.sh /app/models/controlnet "$CONTROLNET_URLS"
RUN /usr/local/bin/download_models.sh /app/models/upscale_models "$UPSCALE_URLS"
RUN /usr/local/bin/download_models.sh /app/models/clip "$CLIP_URLS"
RUN /usr/local/bin/download_models.sh /app/models/unet "$UNET_URLS"
RUN /usr/local/bin/download_models.sh /app/models/text_encoders "$TEXT_ENCODER_URLS"

# ============================================
# Custom Node インストールスクリプト
# ============================================
RUN cat <<'EOF' > /usr/local/bin/install_custom_nodes.sh
#!/bin/bash
# 引数: $1=Custom Node URL一覧（スペースまたは改行区切り）
urls="$1"

[ -z "$urls" ] && exit 0

cd /app/custom_nodes

echo "$urls" | tr ' ' '\n' | while read -r repo_url; do
    # 空行・空白のみをスキップ
    repo_url=$(echo "$repo_url" | xargs)
    [ -z "$repo_url" ] && continue

    # リポジトリ名を取得
    repo_name=$(basename "$repo_url" .git)

    echo "Installing custom node: $repo_name"
    git clone --depth 1 "$repo_url" "$repo_name"

    # requirements.txtがあればインストール
    if [ -f "$repo_name/requirements.txt" ]; then
        echo "Installing requirements for $repo_name"
        pip install -r "$repo_name/requirements.txt"
    fi
done
EOF
RUN chmod +x /usr/local/bin/install_custom_nodes.sh

# ============================================
# Custom Node のインストール
# ============================================
RUN /usr/local/bin/install_custom_nodes.sh "$CUSTOM_NODE_URLS"

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
