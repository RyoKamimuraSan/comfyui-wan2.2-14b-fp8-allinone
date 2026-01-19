# ComfyUI All-in-One Docker Image

ComfyUI を簡単にデプロイできる Docker イメージです。モデルとカスタムノードはコンテナ起動時に自動ダウンロードされます。

## 特徴

- **PyTorch 2.9.1 + CUDA 12.6** ベース
- **aria2** による高速ダウンロード（5並列接続）
- **Filebrowser** でWebからファイル管理
- **JupyterLab** 対応（Paperspace Notebooks用）
- モデル・カスタムノードは起動時にダウンロード（既存ファイルはスキップ）
- 環境変数でURL設定を上書き可能

## クイックスタート

### Docker で実行

```bash
docker run --gpus all -p 8188:8188 -p 8080:8080 yourname/comfyui-allinone
```

### ポート

| ポート | 用途 |
|--------|------|
| 8188 | ComfyUI Web UI |
| 8080 | Filebrowser (admin/admin) |
| 8888 | JupyterLab (Paperspace用) |

## Paperspace Notebooks で使用

1. **Start from Scratch** を選択
2. **Container Image**: `yourname/comfyui-allinone`
3. **Command**: `/app/start-paperspace.sh`

## 環境変数でモデルを設定

起動時に環境変数でモデルURLを上書きできます。

```bash
docker run --gpus all -p 8188:8188 -p 8080:8080 \
  -e CHECKPOINT_URLS="model.safetensors::https://example.com/model.safetensors" \
  -e CUSTOM_NODE_URLS="https://github.com/xxx/yyy" \
  yourname/comfyui-allinone
```

### 対応環境変数

| 環境変数 | 保存先 |
|----------|--------|
| `CHECKPOINT_URLS` | `/app/models/checkpoints` |
| `VAE_URLS` | `/app/models/vae` |
| `LORA_URLS` | `/app/models/loras` |
| `CONTROLNET_URLS` | `/app/models/controlnet` |
| `UPSCALE_URLS` | `/app/models/upscale_models` |
| `CLIP_URLS` | `/app/models/clip` |
| `UNET_URLS` | `/app/models/unet` |
| `TEXT_ENCODER_URLS` | `/app/models/text_encoders` |
| `CUSTOM_NODE_URLS` | `/app/custom_nodes` |

### URL指定形式

```
# ファイル名を指定（推奨）
mymodel.safetensors::https://huggingface.co/xxx/resolve/main/model.safetensors

# URLのみ（Content-Dispositionからファイル名取得）
https://example.com/model.safetensors
```

### 複数指定

スペースまたは改行で区切ります。

```bash
-e CHECKPOINT_URLS="model1.safetensors::https://... model2.safetensors::https://..."
```

## ディレクトリ構造

```
/app/
├── models/
│   ├── checkpoints/
│   ├── vae/
│   ├── loras/
│   ├── controlnet/
│   ├── upscale_models/
│   ├── clip/
│   ├── unet/
│   └── text_encoders/
├── custom_nodes/
├── input/
├── output/
├── start.sh              # スタンドアロン起動用
└── start-paperspace.sh   # Paperspace Notebooks用
```

## ボリュームマウント

データを永続化する場合：

```bash
docker run --gpus all -p 8188:8188 -p 8080:8080 \
  -v $(pwd)/models:/app/models \
  -v $(pwd)/output:/app/output \
  yourname/comfyui-allinone
```

## ビルド

```bash
docker build -t comfyui-allinone .
```

## ライセンス

MIT
