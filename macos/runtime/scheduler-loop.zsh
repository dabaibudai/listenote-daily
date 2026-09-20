#!/bin/zsh
set -u

root_dir="${LISTENOTE_DAILY_ROOT:-$HOME/Library/Application Support/Listenote Daily}"
controller="$root_dir/runtime/schedule-controller.zsh"

while true; do
  /bin/zsh "$controller"
  sleep 30
done
