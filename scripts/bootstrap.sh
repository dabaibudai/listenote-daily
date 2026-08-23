#!/bin/bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Whisper Daily only supports macOS." >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is not installed. Installing it now..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ "$(uname -m)" == "arm64" ]]; then
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
  fi
fi

temp_dir=$(mktemp -d)
cleanup() { rm -rf "$temp_dir"; }
trap cleanup EXIT

echo "Downloading Whisper Daily..."
curl -L --fail --retry 3 --progress-bar \
  https://github.com/dabaibudai/whisper-daily/archive/refs/heads/main.zip \
  -o "$temp_dir/whisper-daily.zip"
/usr/bin/ditto -x -k "$temp_dir/whisper-daily.zip" "$temp_dir"
/bin/zsh "$temp_dir/whisper-daily-main/scripts/install.sh"
