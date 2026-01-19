# ComfyUI All-in-One Docker Image

ComfyUI を簡単にデプロイできる Docker イメージです。モデルは Google Cloud Storage (GCS) からマウントして使用します。

## 特徴

- **PyTorch 2.9.1 + CUDA 12.6** ベース
- **GCS マウント** でモデルを高速読み込み（キャッシュ対応）
- **Filebrowser** でWebからファイル管理
- **JupyterLab** 対応（Paperspace Notebooks用）
- カスタムノードは起動時に自動インストール

## Paperspace Notebooks で使用

### 1. GCS バケットを準備

```bash
# バケット作成
gcloud storage buckets create gs://YOUR_BUCKET_NAME --location=us-central1

# サービスアカウント作成
gcloud iam service-accounts create comfyui-gcs \
    --display-name="ComfyUI GCS Access"

# 権限付与
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:comfyui-gcs@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.objectViewer"

# キー作成
gcloud iam service-accounts keys create gcs-key.json \
    --iam-account=comfyui-gcs@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Base64エンコード
cat gcs-key.json | base64 -w 0
```

### 2. モデルをアップロード

```bash
# ディレクトリ構造に従ってアップロード
gsutil cp model.safetensors gs://YOUR_BUCKET_NAME/checkpoints/
gsutil cp vae.safetensors gs://YOUR_BUCKET_NAME/vae/
```

**GCSバケット構造:**
```
gs://YOUR_BUCKET_NAME/
├── checkpoints/
├── vae/
├── loras/
├── controlnet/
├── upscale_models/
├── clip/
├── unet/
└── text_encoders/
```

### 3. Paperspace で起動

| 設定項目 | 値 |
|----------|-----|
| Container Image | `ryokamimurasan/comfyui-allinone` |
| Command | `/app/start-paperspace.sh` |

**環境変数:**

| 変数名 | 値 |
|--------|-----|
| `GCS_BUCKET` | `YOUR_BUCKET_NAME` |
| `GCS_KEY_BASE64` | `eyJ0eXBlIjoic2VydmljZV9hY2NvdW50Ii...` (Base64値) |

### ポート

| ポート | 用途 |
|--------|------|
| 8188 | ComfyUI Web UI |
| 8080 | Filebrowser (admin/admin) |
| 8888 | JupyterLab |

## ローカル Docker で実行

GCS を使用せずローカルボリュームでモデルを管理する場合：

```bash
docker run --gpus all -p 8188:8188 -p 8080:8080 \
  -v $(pwd)/models:/app/models \
  -v $(pwd)/output:/app/output \
  ryokamimurasan/comfyui-allinone
```

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

## GCS キャッシュ設定

gcsfuse は以下のキャッシュ設定で動作します：

| 設定 | 値 | 説明 |
|------|-----|------|
| file-cache-max-size-mb | -1 | 無制限（ディスク容量まで） |
| stat-cache-ttl | 1h | メタデータキャッシュ1時間 |
| type-cache-ttl | 1h | ディレクトリキャッシュ1時間 |

起動時にバックグラウンドでモデルをプリフェッチし、ローカルキャッシュに保存します。

## ビルド

```bash
docker build -t comfyui-allinone .
```

## ライセンス

MIT
