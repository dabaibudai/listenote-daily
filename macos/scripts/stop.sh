#!/bin/zsh
set -u
root_dir="$HOME/Library/Application Support/Listenote Daily"
rm -f "$root_dir/config/manual.override"
touch "$root_dir/config/pause.override"
launchctl remove com.dabaibudai.listenote-daily.runtime 2>/dev/null || true
echo "Listenote Daily paused until the next scheduled window."
