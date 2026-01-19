#!/usr/bin/env bash
# install.sh - download and run pass2key.sh using domestic mirrors if necessary

set -euo pipefail

SCRIPT="pass2key.sh"
URLS=(
  "https://raw.githubusercontent.com/Ivanbeethoven/ssh_pass2key/master/$SCRIPT"
  "https://ghproxy.com/https://raw.githubusercontent.com/Ivanbeethoven/ssh_pass2key/master/$SCRIPT"
  "https://fastgit.org/Ivanbeethoven/ssh_pass2key/raw/master/$SCRIPT"
  "https://cdn.jsdelivr.net/gh/Ivanbeethoven/ssh_pass2key@$(
    echo master)/$SCRIPT"
)

OUT="/tmp/$SCRIPT"

for url in "${URLS[@]}"; do
  echo "Trying $url"
  if curl -fsSL --max-time 15 "$url" -o "$OUT"; then
    echo "Downloaded from $url"
    chmod +x "$OUT"
    echo "Execute? (y/N)"
    read -r yn
    if [[ "$yn" =~ ^[Yy] ]]; then
      bash "$OUT" --interactive
    else
      echo "Saved to $OUT"
    fi
    exit 0
  else
    echo "Failed to download from $url"
  fi
done

echo "All mirrors failed. Please check your network or manually download $SCRIPT"
exit 2
