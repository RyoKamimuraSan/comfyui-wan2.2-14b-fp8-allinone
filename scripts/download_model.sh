#!/bin/bash
# 引数: $1=出力ディレクトリ, $2=エントリ(ファイル名::URL または URLのみ)
entry="$2"
outdir="$1"

[ -z "$entry" ] && exit 0

if [[ "$entry" == *"::"* ]]; then
    # ファイル名::URL 形式
    filename="${entry%%::*}"
    url="${entry#*::}"
else
    # URLのみ形式
    filename=$(basename "$entry")
    url="$entry"
fi

filepath="$outdir/$filename"

# Civitai URL判定とトークン付与
if [[ "$url" == *"civitai.com"* ]]; then
    if [ -n "$CIVITAI_API_KEY" ]; then
        if [[ "$url" == *"?"* ]]; then
            url="${url}&token=${CIVITAI_API_KEY}"
        else
            url="${url}?token=${CIVITAI_API_KEY}"
        fi
    else
        echo "[WARN] CIVITAI_API_KEY not set. Civitai download may fail: $filename"
    fi
fi

# 既にダウンロード済みならスキップ
if [ -f "$filepath" ]; then
    echo "[SKIP] Already exists: $filename"
    exit 0
fi

echo "[DOWNLOAD] $filename"
if aria2c -x5 \
    --connect-timeout=60 \
    --timeout=600 \
    --max-tries=3 \
    --retry-wait=10 \
    -d "$outdir" -o "$filename" "$url"; then
    echo "[OK] Downloaded: $filename"
else
    echo "[WARN] Failed to download: $filename"
fi
