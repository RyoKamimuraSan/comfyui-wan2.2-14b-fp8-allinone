#!/bin/bash
# 引数: $1=出力ディレクトリ, $2=URL一覧（スペースまたは改行区切り）
outdir="$1"
urls="$2"

[ -z "$urls" ] && exit 0

echo "=== Downloading models to $outdir ==="

echo "$urls" | tr ' ' '\n' | while read -r entry; do
    # 空行・空白のみをスキップ
    entry=$(echo "$entry" | xargs)
    [ -z "$entry" ] && continue
    /usr/local/bin/download_model.sh "$outdir" "$entry"
done
