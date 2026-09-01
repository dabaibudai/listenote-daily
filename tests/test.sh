#!/bin/zsh
set -eu

repo_root="${0:A:h:h}"
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

for script in "$repo_root"/runtime/*.zsh "$repo_root"/scripts/*.sh "$repo_root"/scripts/listenote-daily; do
  /bin/zsh -n "$script"
done
/bin/bash -n "$repo_root/scripts/bootstrap.sh"
/bin/bash -n "$repo_root/vendor/whisper-stream/whisper-stream"

filter="$repo_root/runtime/filter-transcript.zsh"
[ -z "$(printf '明镜需要您的支持 欢迎订阅明镜' | /bin/zsh "$filter")" ]
[ -z "$(printf '请不吝点赞订阅转发打赏支持明镜与点点栏目' | /bin/zsh "$filter")" ]
[ -z "$(printf '中文字幕志愿者 杨茜茜' | /bin/zsh "$filter")" ]
[ "$(printf '这是正常的会议内容' | /bin/zsh "$filter")" = '这是正常的会议内容' ]

sed "s|__HOME__|$HOME|g" \
  "$repo_root/launchd/com.dabaibudai.listenote-daily.scheduler.plist.template" \
  > "$temp_dir/scheduler.plist"
sed "s|__HOME__|$HOME|g" \
  "$repo_root/launchd/com.dabaibudai.listenote-daily.status.plist.template" \
  > "$temp_dir/status.plist"
plutil -lint "$temp_dir/scheduler.plist" "$temp_dir/status.plist" >/dev/null

converted=$(printf '最近兩個月的需求文檔' | "$repo_root/prebuilt/zh-simplify")
[ "$converted" = '最近两个月的需求文档' ]

file "$repo_root/prebuilt/Listenote Daily.app/Contents/MacOS/ListenoteDaily" | grep -q 'universal binary'
file "$repo_root/prebuilt/zh-simplify" | grep -q 'universal binary'
codesign --verify --deep --strict "$repo_root/prebuilt/Listenote Daily.app"

xcrun clang -fobjc-arc -framework Cocoa "$repo_root/tests/status-icon-test.m" -o "$temp_dir/status-icon-test"
"$temp_dir/status-icon-test"

fake_home="$temp_dir/home"
mkdir -p "$fake_home"
legacy_root="$fake_home/Library/Application Support/WhisperDaily"
mkdir -p "$legacy_root/records/transcripts"
printf 'legacy transcript\n' > "$legacy_root/records/transcripts/legacy.md"
HOME="$fake_home" LISTENOTE_DAILY_TEST_MODE=1 /bin/zsh "$repo_root/scripts/install.sh" >/dev/null
test -f "$fake_home/Library/Application Support/Listenote Daily/config/schedule.conf"
test -f "$fake_home/Library/Application Support/Listenote Daily/models/ggml-large-v3-turbo.bin"
test -f "$fake_home/Library/Application Support/Listenote Daily/records/transcripts/legacy.md"
test ! -e "$legacy_root"
test -x "$fake_home/Applications/Listenote Daily.app/Contents/MacOS/ListenoteDaily"
test -L "$fake_home/Listenote Daily Records"

day=$(date +%u)
config="$fake_home/Library/Application Support/Listenote Daily/config/schedule.conf"
printf 'ENABLED=1\nDAYS=%s\nWINDOWS=00:00-23:59\nMODEL_SIZE=large-v3-turbo\nLANGUAGE=zh\n' "$day" > "$config"
controller="$fake_home/Library/Application Support/Listenote Daily/runtime/schedule-controller.zsh"
desired=$(HOME="$fake_home" LISTENOTE_DAILY_DRY_RUN=1 /bin/zsh "$controller")
[ "$desired" = "1" ]
touch "$fake_home/Library/Application Support/Listenote Daily/config/pause.override"
desired=$(HOME="$fake_home" LISTENOTE_DAILY_DRY_RUN=1 /bin/zsh "$controller")
[ "$desired" = "0" ]
touch "$fake_home/Library/Application Support/Listenote Daily/config/manual.override"
desired=$(HOME="$fake_home" LISTENOTE_DAILY_DRY_RUN=1 /bin/zsh "$controller")
[ "$desired" = "1" ]

printf 'ENABLED=1\nDAYS=%s\nWINDOWS=09:00-12:00,13:30-18:00\nMODEL_SIZE=large-v3-turbo\nLANGUAGE=zh\n' "$day" > "$config"
desired=$(HOME="$fake_home" LISTENOTE_DAILY_DRY_RUN=1 LISTENOTE_DAILY_DAY="$day" LISTENOTE_DAILY_NOW=12:00 /bin/zsh "$controller")
[ "$desired" = "0" ]
test ! -e "$fake_home/Library/Application Support/Listenote Daily/config/manual.override"

if rg -n '/Users/liuhao|Documents/[Cc]odex/2026' \
  --glob '!**/README.md' --glob '!**/tests/test.sh' "$repo_root"; then
  echo "Private absolute path found." >&2
  exit 1
fi

echo "All tests passed."
