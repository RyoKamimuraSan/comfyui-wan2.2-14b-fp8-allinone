# ComfyUI All-in-One Docker Image

ComfyUI を簡単にデプロイできる Docker イメージです。モデルとカスタムノードは起動時に自動ダウンロード・インストールされます。

## 特徴

- **PyTorch 2.9.1 + CUDA 12.6** ベース
- **モデル自動ダウンロード** - 環境変数でURLを指定
- **Filebrowser** でWebからファイル管理
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
| 8080 | Filebrowser | - |
| 8888 | JupyterLab | デフォルトURL |

## ローカル Docker で実行

```bash
docker run --gpus all -p 6006:6006 -p 8080:8080 \
  -v $(pwd)/models:/app/models \
  -v $(pwd)/output:/app/output \
  ryokamimurasan/comfyui-allinone
```

ComfyUI: `http://localhost:6006`

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

## ビルド

```bash
docker build -t comfyui-allinone .
```

## ライセンス

MIT
