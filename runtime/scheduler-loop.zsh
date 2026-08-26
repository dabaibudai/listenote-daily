#!/bin/zsh
set -u

root_dir="${WHISPER_DAILY_ROOT:-$HOME/Library/Application Support/WhisperDaily}"
controller="$root_dir/runtime/schedule-controller.zsh"

while true; do
  /bin/zsh "$controller"
  sleep 30
done
