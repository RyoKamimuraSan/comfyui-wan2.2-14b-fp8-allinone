#!/bin/bash
# 引数: $1=Custom Node URL一覧（スペースまたは改行区切り）
urls="$1"

[ -z "$urls" ] && exit 0

cd /app/custom_nodes

echo "=== Installing custom nodes ==="

echo "$urls" | tr ' ' '\n' | while read -r repo_url; do
    # 空行・空白のみをスキップ
    repo_url=$(echo "$repo_url" | xargs)
    [ -z "$repo_url" ] && continue

    # リポジトリ名を取得
    repo_name=$(basename "$repo_url" .git)

    # 既にインストール済みならスキップ
    if [ -d "$repo_name" ]; then
        echo "[SKIP] Already installed: $repo_name"
        continue
    fi

    echo "[INSTALL] $repo_name"

    # git clone with timeout (5min)
    if ! timeout 300 git clone --depth 1 "$repo_url" "$repo_name" 2>&1; then
        echo "[ERROR] Failed to clone $repo_name, removing and skipping..."
        rm -rf "$repo_name"
        continue
    fi

    echo "[OK] Cloned: $repo_name"

    # pip install with timeout (10min)
    if [ -f "$repo_name/requirements.txt" ]; then
        echo "[PIP] Installing requirements for $repo_name"
        if ! timeout 600 pip install -r "$repo_name/requirements.txt" 2>&1; then
            echo "[ERROR] Failed to install requirements for $repo_name, removing and skipping..."
            rm -rf "$repo_name"
            continue
        fi
        echo "[OK] Requirements installed for $repo_name"
    fi
done

echo "=== Custom node installation complete ==="
