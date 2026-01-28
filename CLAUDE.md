# CLAUDE.md - ComfyUI All-in-One 開発ガイド

## プロジェクト概要

ComfyUI を Docker で簡単にデプロイするためのイメージ。Paperspace Notebooks での利用を主なターゲットとする。

## ディレクトリ構造

```
/
├── Dockerfile                    # メイン (wan2.2-14b-fp8)
├── Dockerfile.qwen-image-edit-2511
├── Dockerfile.wan22-smooth-mix
├── scripts/
│   ├── start.sh                  # ローカル Docker 用起動スクリプト
│   ├── start-paperspace.sh       # Paperspace 用起動スクリプト
│   ├── supervisord.conf          # ローカル用 (ComfyUI + JupyterLab)
│   ├── supervisord-paperspace.conf # Paperspace用 (ComfyUI + JupyterLab)
│   ├── download_model.sh         # 単一モデルダウンロード
│   ├── download_models.sh        # 複数モデルダウンロード (バックグラウンド)
│   └── install_custom_nodes.sh   # カスタムノードインストール
└── README.md
```

## 重要な設計ポイント

### 1. Paperspace 起動シーケンス

**JupyterLab は即時起動が必須** - Paperspace はポート 8888 の応答を待つため。

`start-paperspace.sh` の起動順序:
1. `supervisord &` (バックグラウンド) → JupyterLab + ComfyUI 即時起動
2. Storage シンボリックリンク設定
3. カスタムノード追加インストール
4. モデルダウンロード (バックグラウンド)
5. `wait` で supervisord 終了待ち

### 2. supervisord 設定の同期

`supervisord.conf` と `supervisord-paperspace.conf` は**両方とも同じプログラムセクション**を持つ必要がある:
- `[program:comfyui]`
- `[program:jupyterlab]`

変更時は両ファイルを更新すること。

### 3. ログ出力

Docker 環境では stdout/stderr に出力:
```ini
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
```

### 4. ポート

| ポート | 用途 | Paperspace URL |
|--------|------|----------------|
| 6006 | ComfyUI | tensorboard-{id}.paperspacegradient.com |
| 8888 | JupyterLab | デフォルト URL |

## ビルド & テスト

```bash
# ビルド
docker build -t comfyui-allinone .

# ローカル実行
docker run --gpus all -p 6006:6006 -p 8888:8888 comfyui-allinone

# Paperspace モード実行
docker run --gpus all -p 6006:6006 -p 8888:8888 comfyui-allinone /app/start-paperspace.sh
```

## カスタムノード

Impact-Pack は submodule を含むため、Dockerfile で明示的に初期化:
```dockerfile
git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack && \
cd ComfyUI-Impact-Pack && git submodule update --init --depth 1 && cd ..
```

## 環境変数

| 変数 | 用途 |
|------|------|
| CIVITAI_API_KEY | Civitai からのモデルダウンロード認証 |
| CHECKPOINT_URLS | チェックポイントURL (ファイル名::URL 形式) |
| VAE_URLS | VAE URL |
| LORA_URLS | LoRA URL |
| EXTRA_CUSTOM_NODE_URLS | 追加カスタムノード Git URL |
| COMFYUI_EXTRA_ARGS | ComfyUI 追加起動オプション (例: `--fp8_e4m3fn-unet --fp8_e4m3fn-text-enc`) |
