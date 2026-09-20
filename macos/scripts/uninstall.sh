#!/bin/zsh
set -eu

runtime_root="$HOME/Library/Application Support/Listenote Daily"
agents_dir="$HOME/Library/LaunchAgents"
uid=$(id -u)
stamp=$(date +%Y%m%d-%H%M%S)
trash_dir="$HOME/.Trash/ListenoteDaily-uninstalled-$stamp"

launchctl remove com.dabaibudai.listenote-daily.runtime 2>/dev/null || true
launchctl bootout "gui/$uid" "$agents_dir/com.dabaibudai.listenote-daily.scheduler.plist" 2>/dev/null || true
launchctl bootout "gui/$uid" "$agents_dir/com.dabaibudai.listenote-daily.status.plist" 2>/dev/null || true
mkdir -p "$trash_dir"

for target in \
  "$runtime_root" \
  "$HOME/Applications/Listenote Daily.app" \
  "$agents_dir/com.dabaibudai.listenote-daily.scheduler.plist" \
  "$agents_dir/com.dabaibudai.listenote-daily.status.plist"; do
  [ -e "$target" ] && mv "$target" "$trash_dir/"
done

for prefix in /opt/homebrew /usr/local; do
  [ -L "$prefix/bin/listenote-daily" ] && rm -f "$prefix/bin/listenote-daily"
  [ -L "$prefix/bin/whisper-daily" ] && rm -f "$prefix/bin/whisper-daily"
done
[ -L "$HOME/Listenote Daily Records" ] && rm -f "$HOME/Listenote Daily Records"

echo "Uninstalled to Trash: $trash_dir"
echo "Homebrew dependencies were preserved because they may be shared."
