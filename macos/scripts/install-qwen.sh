#!/bin/zsh
set -eu

runtime_root="${LISTENOTE_DAILY_ROOT:-$HOME/Library/Application Support/Listenote Daily}"
script_dir="${0:A:h}"
venv="$runtime_root/qwen-venv"
cache="$runtime_root/qwen-cache"
model="moona3k/mlx-qwen3-asr-0.6b-8bit"
revision="83ce2a8ef9a382d2ba2209aab383bc51fff366f5"

if [ "$(uname -m)" != "arm64" ]; then
  print -r -- "Qwen MLX requires an Apple Silicon Mac." >&2
  exit 1
fi
if ! command -v uv >/dev/null 2>&1; then
  print -r -- "uv is required for the local Qwen Python environment." >&2
  exit 1
fi

mkdir -p "$cache"
if [ ! -x "$venv/bin/python" ]; then
  uv python install 3.12
  uv venv --python 3.12 "$venv"
fi
uv pip install --python "$venv/bin/python" -r "$script_dir/qwen-requirements.txt"

export HF_HOME="$cache" HF_HUB_DISABLE_XET=1
"$venv/bin/python" -c '
from huggingface_hub import snapshot_download
from pathlib import Path
import os, sys
model, revision = sys.argv[1:]
snapshot_download(repo_id=model, revision=revision)
ref = Path(os.environ["HF_HOME"]) / "hub" / ("models--" + model.replace("/", "--")) / "refs" / "main"
ref.parent.mkdir(parents=True, exist_ok=True)
ref.write_text(revision)
' "$model" "$revision"
print -r -- "Qwen 0.6B ready: $venv and $cache"
