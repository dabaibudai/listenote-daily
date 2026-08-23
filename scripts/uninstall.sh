#!/bin/zsh
set -eu

runtime_root="$HOME/Library/Application Support/WhisperDaily"
agents_dir="$HOME/Library/LaunchAgents"
uid=$(id -u)
stamp=$(date +%Y%m%d-%H%M%S)
trash_dir="$HOME/.Trash/WhisperDaily-uninstalled-$stamp"

launchctl remove com.dabaibudai.whisper-daily.runtime 2>/dev/null || true
launchctl bootout "gui/$uid" "$agents_dir/com.dabaibudai.whisper-daily.scheduler.plist" 2>/dev/null || true
launchctl bootout "gui/$uid" "$agents_dir/com.dabaibudai.whisper-daily.status.plist" 2>/dev/null || true
mkdir -p "$trash_dir"

for target in \
  "$runtime_root" \
  "$HOME/Applications/WhisperDaily.app" \
  "$agents_dir/com.dabaibudai.whisper-daily.scheduler.plist" \
  "$agents_dir/com.dabaibudai.whisper-daily.status.plist"; do
  [ -e "$target" ] && mv "$target" "$trash_dir/"
done

for prefix in /opt/homebrew /usr/local; do
  [ -L "$prefix/bin/whisper-daily" ] && rm -f "$prefix/bin/whisper-daily"
done
[ -L "$HOME/WhisperDaily Records" ] && rm -f "$HOME/WhisperDaily Records"

echo "Uninstalled to Trash: $trash_dir"
echo "Homebrew dependencies were preserved because they may be shared."
