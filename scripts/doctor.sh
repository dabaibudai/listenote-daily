#!/bin/zsh
set -u
root_dir="$HOME/Library/Application Support/WhisperDaily"
failed=0

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

if command -v whisper-cli >/dev/null 2>&1 \
  || [ -x /opt/homebrew/opt/whisper-cpp/bin/whisper-cli ] \
  || [ -x /usr/local/opt/whisper-cpp/bin/whisper-cli ]; then
  echo "OK   whisper-cli"
else
  echo "MISS whisper-cli"
  failed=1
fi

check_file "$root_dir/models/ggml-medium.bin"
check_file "$root_dir/models/ggml-silero-v5.1.2.bin"
check_file "$root_dir/runtime/run.zsh"
check_file "$HOME/Applications/WhisperDaily.app"

/bin/zsh "$root_dir/scripts/status.sh" 2>/dev/null || true
exit "$failed"
