#!/bin/zsh
set -u
root_dir="$HOME/Library/Application Support/WhisperDaily"
rm -f "$root_dir/config/manual.override"
touch "$root_dir/config/pause.override"
launchctl remove com.dabaibudai.whisper-daily.runtime 2>/dev/null || true
echo "Whisper Daily paused until the next scheduled window."
