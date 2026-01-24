#!/bin/bash
# 引数: $1=出力ディレクトリ, $2=URL一覧（スペースまたは改行区切り）, $3=並列数（オプション、デフォルト4）
outdir="$1"
urls="$2"
parallel="${3:-4}"

[ -z "$urls" ] && exit 0

echo "=== Downloading models to $outdir (parallel: $parallel) ==="

# URL一覧を一時ファイルに書き出し
tmpfile=$(mktemp)
echo "$urls" | tr ' ' '\n' | while read -r entry; do
    entry=$(echo "$entry" | xargs)
    [ -z "$entry" ] && continue
    echo "$entry"
done > "$tmpfile"

# xargsで並列ダウンロード
cat "$tmpfile" | xargs -P"$parallel" -I{} /usr/local/bin/download_model.sh "$outdir" "{}"

rm -f "$tmpfile"
