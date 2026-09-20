#!/bin/zsh
set -eu
root_dir="$HOME/Library/Application Support/Listenote Daily"
mkdir -p "$root_dir/config"
rm -f "$root_dir/config/pause.override"
touch "$root_dir/config/manual.override"
/bin/zsh "$root_dir/runtime/schedule-controller.zsh"
echo "Listenote Daily started (manual override)."
