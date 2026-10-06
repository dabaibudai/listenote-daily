#!/bin/zsh
set -u
root_dir="$HOME/Library/Application Support/Listenote Daily"
failed=0
config_file="$root_dir/config/schedule.conf"
[ -f "$config_file" ] && source "$config_file"
asr_backend="${ASR_BACKEND:-whisper}"

check_file() {
  if [ -e "$1" ]; then echo "OK   $1"; else echo "MISS $1"; failed=1; fi
}

for command in brew jq sox rec rg; do
  if command -v "$command" >/dev/null 2>&1; then
    echo "OK   $command"
  else
    echo "MISS $command"
    failed=1
  fi
done

if [ "$asr_backend" = "qwen" ]; then
  if [ "$(uname -m)" = "arm64" ]; then echo "OK   Apple Silicon"; else echo "MISS Apple Silicon (Qwen MLX)"; failed=1; fi
  if command -v ffmpeg >/dev/null 2>&1; then echo "OK   ffmpeg"; else echo "MISS ffmpeg"; failed=1; fi
  if [ -x "$root_dir/qwen-venv/bin/python" ] && "$root_dir/qwen-venv/bin/python" -c 'from importlib.metadata import version; assert version("mlx-qwen3-asr") == "0.4.4"' >/dev/null 2>&1; then
    echo "OK   Qwen Python and mlx-qwen3-asr 0.4.4"
  else
    echo "MISS Qwen Python or mlx-qwen3-asr 0.4.4"
    failed=1
  fi
  model_snapshot="$root_dir/qwen-cache/hub/models--moona3k--mlx-qwen3-asr-0.6b-8bit/snapshots/83ce2a8ef9a382d2ba2209aab383bc51fff366f5"
  check_file "$model_snapshot/weights.safetensors"
  check_file "$root_dir/runtime/qwen-server.py"
else
  if command -v whisper-cli >/dev/null 2>&1 \
    || [ -x /opt/homebrew/opt/whisper-cpp/bin/whisper-cli ] \
    || [ -x /usr/local/opt/whisper-cpp/bin/whisper-cli ]; then
    echo "OK   whisper-cli"
  else
    echo "MISS whisper-cli"
    failed=1
  fi
  check_file "$root_dir/models/ggml-large-v3-turbo.bin"
  check_file "$root_dir/models/ggml-silero-v5.1.2.bin"
fi

check_file "$root_dir/runtime/run.zsh"
check_file "$HOME/Applications/Listenote Daily.app"

/bin/zsh "$root_dir/scripts/status.sh" 2>/dev/null || true
exit "$failed"
