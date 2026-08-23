#!/bin/zsh
set -eu

repo_root="${0:A:h:h}"
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

for script in "$repo_root"/runtime/*.zsh "$repo_root"/scripts/*.sh "$repo_root"/scripts/whisper-daily; do
  /bin/zsh -n "$script"
done
/bin/bash -n "$repo_root/scripts/bootstrap.sh"
/bin/bash -n "$repo_root/vendor/whisper-stream/whisper-stream"

sed "s|__HOME__|$HOME|g" \
  "$repo_root/launchd/com.dabaibudai.whisper-daily.scheduler.plist.template" \
  > "$temp_dir/scheduler.plist"
sed "s|__HOME__|$HOME|g" \
  "$repo_root/launchd/com.dabaibudai.whisper-daily.status.plist.template" \
  > "$temp_dir/status.plist"
plutil -lint "$temp_dir/scheduler.plist" "$temp_dir/status.plist" >/dev/null

converted=$(printf '最近兩個月的需求文檔' | "$repo_root/prebuilt/zh-simplify")
[ "$converted" = '最近两个月的需求文档' ]

file "$repo_root/prebuilt/WhisperDaily.app/Contents/MacOS/WhisperDaily" | grep -q 'universal binary'
file "$repo_root/prebuilt/zh-simplify" | grep -q 'universal binary'
codesign --verify --deep --strict "$repo_root/prebuilt/WhisperDaily.app"

fake_home="$temp_dir/home"
mkdir -p "$fake_home"
HOME="$fake_home" WHISPER_DAILY_TEST_MODE=1 /bin/zsh "$repo_root/scripts/install.sh" >/dev/null
test -f "$fake_home/Library/Application Support/WhisperDaily/config/schedule.conf"
test -f "$fake_home/Library/Application Support/WhisperDaily/models/ggml-medium.bin"
test -x "$fake_home/Applications/WhisperDaily.app/Contents/MacOS/WhisperDaily"
test -L "$fake_home/WhisperDaily Records"

day=$(date +%u)
config="$fake_home/Library/Application Support/WhisperDaily/config/schedule.conf"
printf 'ENABLED=1\nDAYS=%s\nWINDOWS=00:00-23:59\nMODEL_SIZE=medium\nLANGUAGE=zh\n' "$day" > "$config"
controller="$fake_home/Library/Application Support/WhisperDaily/runtime/schedule-controller.zsh"
desired=$(HOME="$fake_home" WHISPER_DAILY_DRY_RUN=1 /bin/zsh "$controller")
[ "$desired" = "1" ]
touch "$fake_home/Library/Application Support/WhisperDaily/config/pause.override"
desired=$(HOME="$fake_home" WHISPER_DAILY_DRY_RUN=1 /bin/zsh "$controller")
[ "$desired" = "0" ]
touch "$fake_home/Library/Application Support/WhisperDaily/config/manual.override"
desired=$(HOME="$fake_home" WHISPER_DAILY_DRY_RUN=1 /bin/zsh "$controller")
[ "$desired" = "1" ]

if rg -n '/Users/liuhao|Documents/[Cc]odex/2026' \
  --glob '!**/README.md' --glob '!**/tests/test.sh' "$repo_root"; then
  echo "Private absolute path found." >&2
  exit 1
fi

echo "All tests passed."
