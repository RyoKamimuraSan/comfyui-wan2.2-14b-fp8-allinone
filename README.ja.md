# ComfyUI All-in-One Docker Image

ComfyUI を簡単にデプロイできる Docker イメージ。モデルの自動ダウンロードと JupyterLab を統合しています。

## 特徴

- **モデル自動ダウンロード** - 環境変数で指定したモデルが起動時に自動ダウンロード
- **JupyterLab 統合** - ノートブック作業やファイル管理に対応
- **カスタムノード プリインストール** - 人気のノードがすぐに使える
- **PyTorch 2.9.1 + CUDA 12.6** - 最新のディープラーニング環境

## 動作確認済みプラットフォーム

- Paperspace Notebooks
- RunPod
- ローカル Docker

**Docker Hub**: [ryokamimurasan](https://hub.docker.com/u/ryokamimurasan)

---

## Paperspace Notebooks

### セットアップ

| 設定項目 | 値 |
|----------|-----|
| Container Image | `ryokamimurasan/comfyui-wan22-14b-fp8-paperspace-nb` |
| Command | `/app/start-paperspace.sh` |

### サービスへのアクセス

| サービス | ポート | URL形式 |
|----------|--------|---------|
| ComfyUI | 6006 | `https://tensorboard-{notebook-id}.paperspacegradient.com` |
| JupyterLab | 8888 | デフォルトの Paperspace URL |

**例:**
- JupyterLab: `https://abc123.xyz456.paperspacegradient.com`
- ComfyUI: `https://tensorboard-abc123.xyz456.paperspacegradient.com`

### キープアライブ機能

Paperspace モードでは自動的に有効化されます。15分ごとにビーコンを送信してアイドルシャットダウンを防止します。

### ストレージ永続化

以下のディレクトリが `/storage` に自動リンクされ永続化されます：

| ローカルパス | リンク先 |
|--------------|----------|
| `/app/output` | `/storage/output` |
| `/app/user/default/workflows` | `/storage/workflow` |

---

## RunPod

RunPod での動作を確認済み。`/workspace` でストレージが永続化され、Paperspace と同様の機能が使えます。

---

## ローカル Docker

### 基本的な使い方

```bash
docker run --gpus all -p 6006:6006 -p 8888:8888 \
  ryokamimurasan/comfyui-wan22-14b-fp8-paperspace-nb
```

### ボリュームマウント（推奨）

```bash
docker run --gpus all -p 6006:6006 -p 8888:8888 \
  -v $(pwd)/models:/app/models \
  -v $(pwd)/output:/app/output \
  ryokamimurasan/comfyui-wan22-14b-fp8-paperspace-nb
```

### アクセス

| サービス | URL |
|----------|-----|
| ComfyUI | `http://localhost:6006` |
| JupyterLab | `http://localhost:8888` |

---

## Paperspace vs ローカル Docker

| 項目 | Paperspace | ローカル Docker |
|------|------------|-----------------|
| コマンド | `/app/start-paperspace.sh` | (デフォルト entrypoint) |
| キープアライブ | 自動有効 | 不要 |
| ストレージ | `/storage` 自動リンク | `-v` でボリュームマウント |
| アクセス | Paperspace プロキシ URL 経由 | `localhost:port` |

---

## 利用可能なイメージ

| イメージ | 用途 | デフォルトモデル |
|----------|------|------------------|
| `ryokamimurasan/comfyui-wan22-14b-fp8-paperspace-nb` | Wan2.2 14B 動画生成 | Wan2.2 Remix NSFW i2v 14b, wan 2.1 VAE, 4x-UltraSharp |
| `ryokamimurasan/comfyui-qwen-image-edit-2511-paperspace-nb` | Qwen による画像編集 | Qwen Image Edit fp8, 2dn_animeV3, qwen_2.5_vl_7b |
| `ryokamimurasan/comfyui-wan22-smooth-mix-v2-paperspace-nb` | Wan2.2 smooth-mix 動画 | smoothMixWan22 i2v モデル, LightX2V LoRA |

### comfyui-wan22-14b-fp8-paperspace-nb（デフォルト）

Wan2.2 14B 動画生成に最適化：
- Wan2.2 Remix NSFW i2v 14b (high/low lighting)
- wan 2.1 VAE
- 4x-UltraSharp アップスケーラー
- nsfw_wan_umt5-xxl_fp8_scaled テキストエンコーダー

### comfyui-qwen-image-edit-2511-paperspace-nb

Qwen ベースの画像編集に最適化：
- qwen_image_edit_2511_fp8 lightning 8-steps
- 2dn_animeV3 チェックポイント
- qwen_2.5_vl_7b_fp8 テキストエンコーダー
- Ultralytics BBOX セグメンテーションモデル

**注意:** 一部のモデルには `CIVITAI_API_KEY` が必要です。

### comfyui-wan22-smooth-mix-v2-paperspace-nb

smooth-mix 動画生成に最適化：
- smoothMixWan22 14B i2v (high/low バージョン)
- LightX2V step distill LoRA
- CLIP Vision モデル
- fp8 と bf16 両方のテキストエンコーダー

---

## 設定

### 環境変数

| 変数 | 説明 | 形式 |
|------|------|------|
| `CIVITAI_API_KEY` | Civitai API キー（モデルダウンロードと Civicomfy 用） | API キー文字列 |
| `CHECKPOINT_URLS` | チェックポイントモデル | `ファイル名::URL`（スペース区切り） |
| `VAE_URLS` | VAE モデル | `ファイル名::URL` |
| `LORA_URLS` | LoRA モデル | `ファイル名::URL` |
| `CONTROLNET_URLS` | ControlNet モデル | `ファイル名::URL` |
| `UPSCALE_URLS` | アップスケールモデル | `ファイル名::URL` |
| `CLIP_URLS` | CLIP モデル | `ファイル名::URL` |
| `CLIP_VISION_URLS` | CLIP Vision モデル | `ファイル名::URL` |
| `TEXT_ENCODER_URLS` | テキストエンコーダー | `ファイル名::URL` |
| `DIFFUSION_MODEL_URLS` | Diffusion モデル | `ファイル名::URL` |
| `UNET_URLS` | UNet モデル | `ファイル名::URL` |
| `ULTRALYTICS_BBOX_URLS` | Ultralytics BBOX モデル | `ファイル名::URL` |
| `EXTRA_CUSTOM_NODE_URLS` | 追加カスタムノード | Git URL（スペース区切り） |

### 使用例

```bash
docker run --gpus all -p 6006:6006 \
  -e CIVITAI_API_KEY=your_api_key \
  -e LORA_URLS="style.safetensors::https://example.com/style.safetensors" \
  ryokamimurasan/comfyui-wan22-14b-fp8-paperspace-nb
```

### Civitai API キー

`CIVITAI_API_KEY` を設定すると以下が有効になります：
1. **モデルダウンロード** - Civitai URL からのダウンロード時の認証
2. **Civicomfy 連携** - API キーが Civicomfy の設定に自動注入

---

## プリインストール済みカスタムノード

| ノード | リポジトリ |
|--------|------------|
| ComfyUI-Manager | [ltdrdata/ComfyUI-Manager](https://github.com/ltdrdata/ComfyUI-Manager) |
| Civicomfy | [Civitai/civitai_comfy_nodes](https://github.com/Civitai/civitai_comfy_nodes) |
| ComfyUI-VideoHelperSuite | [Kosinkadink/ComfyUI-VideoHelperSuite](https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite) |
| ComfyUI-Impact-Pack | [ltdrdata/ComfyUI-Impact-Pack](https://github.com/ltdrdata/ComfyUI-Impact-Pack) |
| ComfyUI-RMBG | [ssitu/ComfyUI-RMBG](https://github.com/ssitu/ComfyUI-RMBG) |
| rgthree-comfy | [rgthree/rgthree-comfy](https://github.com/rgthree/rgthree-comfy) |
| ComfyUI-KJNodes | [kijai/ComfyUI-KJNodes](https://github.com/kijai/ComfyUI-KJNodes) |
| ComfyUI-Frame-Interpolation | [Fannovel16/ComfyUI-Frame-Interpolation](https://github.com/Fannovel16/ComfyUI-Frame-Interpolation) |
| ComfyUI-Custom-Scripts | [pythongosssss/ComfyUI-Custom-Scripts](https://github.com/pythongosssss/ComfyUI-Custom-Scripts) |
| ComfyUI-WanVideoWrapper* | [kijai/ComfyUI-WanVideoWrapper](https://github.com/kijai/ComfyUI-WanVideoWrapper) |

*ComfyUI-WanVideoWrapper は `comfyui-wan22-14b-fp8-paperspace-nb` と `comfyui-wan22-smooth-mix-v2-paperspace-nb` イメージにのみ含まれています。

---

## ソースからビルド

```bash
# メインイメージ
docker build -t comfyui-allinone .

# Qwen Image Edit イメージ
docker build -f Dockerfile.qwen-image-edit-2511 -t comfyui-qwen-image-edit-2511 .

# Wan22 Smooth Mix イメージ
docker build -f Dockerfile.wan22-smooth-mix -t comfyui-wan22-smooth-mix .
```

---

## ライセンス

MIT
