#!/bin/bash
# Free itch.io download, used by tools/fetch_assets.sh.
# usage: itch_dl.sh <user> <game-slug> <outdir> [file-name-regex]
# Free itch.io download, same requests as itch's own JS (extern.min.js download_upload):
# POST /<slug>/download_url -> download page; POST /<slug>/file/<upload_id>?source=game_download&after_download_lightbox=1&as_props=1
set -e
U=$1; G=$2; OUT=$3; FILT=${4:-.}
UA="Mozilla/5.0 (X11; Linux x86_64)"; J=$(mktemp); B="https://$U.itch.io/$G"
mkdir -p "$OUT"
csrf=$(curl -s -A "$UA" -c $J -b $J --max-time 30 "$B" | grep -oE '<meta name="csrf_token" value="[^"]+"' | sed -E 's/.*value="//;s/"$//')
durl=$(curl -s -A "$UA" -c $J -b $J --max-time 30 -X POST -d "csrf_token=$csrf" -H "X-Requested-With: XMLHttpRequest" "$B/download_url" | python3 -c "import sys,json; print(json.load(sys.stdin)['url'])")
page=$(curl -s -A "$UA" -c $J -b $J --max-time 30 "$durl")
csrf2=$(echo "$page" | grep -oE '<meta name="csrf_token" value="[^"]+"' | sed -E 's/.*value="//;s/"$//')
echo "$page" | python3 -c "
import sys,re
h=sys.stdin.read()
for m in re.finditer(r'data-upload_id=\"(\d+)\".*?class=\"name\" title=\"([^\"]+)\"', h, re.S):
    print(m.group(1)+'\t'+m.group(2))
" > "$OUT/uploads.tsv"
cat "$OUT/uploads.tsv"
while IFS=$'\t' read id name; do
  echo "$name" | grep -qiE "$FILT" || continue
  furl=$(curl -s -A "$UA" -c $J -b $J --max-time 30 -X POST --data-urlencode "csrf_token=$csrf2" -H "X-Requested-With: XMLHttpRequest" -H "Referer: $durl" "$B/file/$id?source=game_download&after_download_lightbox=1&as_props=1" | python3 -c "import sys,json; print(json.load(sys.stdin)['url'])")
  echo "-> $name"
  curl -sL -A "$UA" --max-time 1500 -o "$OUT/$name" "$furl"
  ls -la "$OUT/$name" | awk '{print $5, $9}'
done < "$OUT/uploads.tsv"
