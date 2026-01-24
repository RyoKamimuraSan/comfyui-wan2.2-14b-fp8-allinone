# ComfyUI All-in-One Docker Image

ComfyUI を簡単にデプロイできる Docker イメージです。モデルとカスタムノードは起動時に自動ダウンロード・インストールされます。

## 特徴

- **PyTorch 2.9.1 + CUDA 12.6** ベース
- **モデル自動ダウンロード** - 環境変数でURLを指定
- **JupyterLab** 対応（Paperspace Notebooks用）
- カスタムノードは起動時に自動インストール

## Paperspace Notebooks で使用

### 1. Paperspace で起動

| 設定項目 | 値 |
|----------|-----|
| Container Image | `ryokamimurasan/comfyui-allinone` |
| Command | `/app/start-paperspace.sh` |

### 2. ComfyUI にアクセス

ComfyUIはTensorBoardポート（6006）で起動するため、以下のURL形式でアクセス：

```
https://tensorboard-{notebook-id}.{domain}.paperspacegradient.com
```

**例:**
- JupyterLab: `https://abc123.xyz456.paperspacegradient.com`
- ComfyUI: `https://tensorboard-abc123.xyz456.paperspacegradient.com`

### ポート

| ポート | 用途 | アクセス方法 |
|--------|------|-------------|
| 6006 | ComfyUI Web UI | TensorBoard URL |
| 8888 | JupyterLab | デフォルトURL |

## ローカル Docker で実行

```bash
docker run --gpus all -p 6006:6006 \
  -v $(pwd)/models:/app/models \
  -v $(pwd)/output:/app/output \
  ryokamimurasan/comfyui-allinone
```

ComfyUI: `http://localhost:6006`

## Storage 永続化

`/storage` ディレクトリがマウントされている場合、以下のシンボリックリンクが自動作成されます：

| ローカルパス | リンク先 |
|-------------|---------|
| `/app/output` | `/storage/output` |
| `/app/user/default/workflows` | `/storage/workflow` |

これにより、出力ファイルとワークフローが永続化されます。

## モデルの設定

環境変数でダウンロードするモデルURLを指定できます。

```bash
-e CHECKPOINT_URLS="model.safetensors::https://example.com/model.safetensors"
-e VAE_URLS="vae.safetensors::https://example.com/vae.safetensors"
-e LORA_URLS="lora.safetensors::https://example.com/lora.safetensors"
```

**書式:** `ファイル名::URL`（スペース区切りで複数指定可能）

**デフォルトでダウンロードされるモデル:**
- Wan2.2 Remix NSFW i2v 14b (high/low lighting)
- wan 2.1 VAE
- 4x-UltraSharp (upscale)
- nsfw_wan_umt5-xxl_fp8_scaled (text encoder)

## カスタムノードの設定

環境変数 `CUSTOM_NODE_URLS` でインストールするカスタムノードを指定できます。

```bash
-e CUSTOM_NODE_URLS="https://github.com/xxx/yyy https://github.com/aaa/bbb"
```

**デフォルトでインストールされるカスタムノード:**
- ComfyUI-Manager
- Civicomfy
- ComfyUI-VideoHelperSuite
- ComfyUI-Impact-Pack
- ComfyUI-RMBG
- rgthree-comfy
- ComfyUI-KJNodes
- ComfyUI-Frame-Interpolation
- ComfyUI-Custom-Scripts

## qwen-image-edit-2511 版

qwen-image-edit-2511 用に最適化されたイメージ：

```bash
docker pull ryokamimurasan/comfyui-qwen-image-edit-2511
```

### デフォルトでダウンロードされるモデル

| カテゴリ | モデル名 | ソース |
|---------|---------|--------|
| checkpoints | 2dn_animeV3.safetensors | Civitai |
| diffusion_models | qwen_image_edit_2511_fp8_e4m3fn_scaled_lightning_8steps_v1.0.safetensors | HuggingFace |
| loras | qwen-image_nsfw_adv_v1.0.safetensors | Civitai |
| loras | NoobV065sHyperDmd.safetensors | HuggingFace |
| text_encoders | qwen_2.5_vl_7b_fp8_scaled.safetensors | HuggingFace |
| vae | qwen_image_vae.safetensors | HuggingFace |
| upscale_models | 4x-UltraSharp.pth | HuggingFace |
| ultralytics/bbox | Anzhc Breasts Seg v1 1024m.pt | HuggingFace |
| ultralytics/bbox | Anzhc Eyes -seg-hd.pt | HuggingFace |
| ultralytics/bbox | Anzhc Face -seg.pt | HuggingFace |

### ビルド

```bash
docker build -f Dockerfile.qwen-image-edit-2511 -t comfyui-qwen-image-edit-2511 .
```

### 実行

```bash
docker run --gpus all -p 6006:6006 \
  -e CIVITAI_API_KEY=your_api_key \
  ryokamimurasan/comfyui-qwen-image-edit-2511
```

**注意:**
- Civitaiモデルをダウンロードするには、実行時に `CIVITAI_API_KEY` 環境変数が必要です
- APIキーがない場合、Civitaiモデルはスキップされます

## wan22-smooth-mix 版

Wan2.2 smooth-mix モデル用に最適化されたイメージ：

```bash
docker pull ryokamimurasan/comfyui-wan22-smooth-mix
```

### デフォルトでダウンロードされるモデル

| カテゴリ | モデル名 | ソース |
|---------|---------|--------|
| diffusion_models | smoothMixWan2214BI2V_i2vV20Low.safetensors | HuggingFace |
| diffusion_models | smoothMixWan2214BI2V_i2vV20High.safetensors | HuggingFace |
| vae | wan_2.1_vae.safetensors | HuggingFace |
| text_encoders | nsfw_wan_umt5-xxl_fp8_scaled.safetensors | HuggingFace |
| text_encoders | nsfw_wan_umt5-xxl_bf16.safetensors | HuggingFace |
| clip_vision | clip_vision_h.safetensors | HuggingFace |
| loras | lightx2v_T2V_14B_cfg_step_distill_v2_lora_rank128_bf16.safetensors | HuggingFace |
| upscale_models | 4x-UltraSharp.pth | HuggingFace |

### ビルド

```bash
docker build -f Dockerfile.wan22-smooth-mix -t comfyui-wan22-smooth-mix .
```

### 実行

```bash
docker run --gpus all -p 6006:6006 \
  -e CIVITAI_API_KEY=your_api_key \
  ryokamimurasan/comfyui-wan22-smooth-mix
```

## Civitai API キー

`CIVITAI_API_KEY` 環境変数を設定すると、以下の機能が有効になります：

1. **モデルダウンロード** - Civitai URLからのモデル直接ダウンロード時に認証
2. **Civicomfy** - ブラウザでComfyUIを開くと、APIキーが自動的にCivicomfyの設定に注入されます

```bash
docker run --gpus all -p 6006:6006 \
  -e CIVITAI_API_KEY=your_api_key \
  ryokamimurasan/comfyui-allinone
```

## ビルド

```bash
docker build -t comfyui-allinone .
```

## ライセンス

MIT
