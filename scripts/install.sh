#!/bin/zsh
set -eu

repo_root="${0:A:h:h}"
runtime_root="$HOME/Library/Application Support/WhisperDaily"
app_path="$HOME/Applications/WhisperDaily.app"
agents_dir="$HOME/Library/LaunchAgents"
uid=$(id -u)
test_mode="${WHISPER_DAILY_TEST_MODE:-0}"

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Whisper Daily only supports macOS." >&2
  exit 1
fi
if [ "$test_mode" != "1" ] && ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required. Run scripts/bootstrap.sh for a zero-to-ready install." >&2
  exit 1
fi

echo "[1/6] Installing command-line dependencies"
if [ "$test_mode" != "1" ]; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install jq sox whisper-cpp ripgrep
else
  echo "      Test mode: skipped"
fi

echo "[2/6] Installing runtime"
mkdir -p "$runtime_root/bin" "$runtime_root/config" "$runtime_root/models" \
  "$runtime_root/records/transcripts" "$runtime_root/records/logs" \
  "$runtime_root/runtime" "$runtime_root/scripts" "$runtime_root/vendor/whisper-stream" \
  "$HOME/Applications" "$agents_dir"
ditto "$repo_root/runtime" "$runtime_root/runtime"
ditto "$repo_root/scripts" "$runtime_root/scripts"
ditto "$repo_root/vendor/whisper-stream" "$runtime_root/vendor/whisper-stream"
cp "$repo_root/prebuilt/zh-simplify" "$runtime_root/bin/zh-simplify"
if [ ! -f "$runtime_root/config/schedule.conf" ]; then
  cp "$repo_root/config/schedule.conf" "$runtime_root/config/schedule.conf"
fi
chmod +x "$runtime_root"/runtime/*.zsh "$runtime_root"/scripts/* \
  "$runtime_root/vendor/whisper-stream/whisper-stream" "$runtime_root/bin/zh-simplify"

download_model() {
  local url="$1" destination="$2" expected="$3" actual=""
  if [ -f "$destination" ]; then
    actual=$(shasum -a 256 "$destination" | awk '{print $1}')
    if [ "$actual" = "$expected" ]; then
      echo "      Reusing ${destination:t}"
      return 0
    fi
    mv "$destination" "$destination.invalid-$(date +%Y%m%d%H%M%S)"
  fi
  echo "      Downloading ${destination:t}"
  curl -L --fail --retry 3 --progress-bar "$url" -o "$destination.part"
  actual=$(shasum -a 256 "$destination.part" | awk '{print $1}')
  if [ "$actual" != "$expected" ]; then
    echo "Checksum mismatch for ${destination:t}" >&2
    exit 1
  fi
  mv "$destination.part" "$destination"
}

echo "[3/6] Downloading local models (Medium is about 1.4 GB)"
if [ "$test_mode" != "1" ]; then
  download_model \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin" \
    "$runtime_root/models/ggml-medium.bin" \
    "6c14d5adee5f86394037b4e4e8b59f1673b6cee10e3cf0b11bbdbee79c156208"
  download_model \
    "https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin" \
    "$runtime_root/models/ggml-silero-v5.1.2.bin" \
    "29940d98d42b91fbd05ce489f3ecf7c72f0a42f027e4875919a28fb4c04ea2cf"
else
  touch "$runtime_root/models/ggml-medium.bin" "$runtime_root/models/ggml-silero-v5.1.2.bin"
  echo "      Test mode: created placeholders"
fi

echo "[4/6] Installing menu bar app"
ditto "$repo_root/prebuilt/WhisperDaily.app" "$app_path"
codesign --force --sign - "$app_path" >/dev/null

echo "[5/6] Installing configurable scheduler"
sed "s|__HOME__|$HOME|g" \
  "$repo_root/launchd/com.dabaibudai.whisper-daily.scheduler.plist.template" \
  > "$agents_dir/com.dabaibudai.whisper-daily.scheduler.plist"
sed "s|__HOME__|$HOME|g" \
  "$repo_root/launchd/com.dabaibudai.whisper-daily.status.plist.template" \
  > "$agents_dir/com.dabaibudai.whisper-daily.status.plist"
plutil -lint "$agents_dir/com.dabaibudai.whisper-daily.scheduler.plist" >/dev/null
plutil -lint "$agents_dir/com.dabaibudai.whisper-daily.status.plist" >/dev/null

if [ "$test_mode" != "1" ]; then
  launchctl bootout "gui/$uid" "$agents_dir/com.dabaibudai.whisper-daily.scheduler.plist" 2>/dev/null || true
  launchctl bootout "gui/$uid" "$agents_dir/com.dabaibudai.whisper-daily.status.plist" 2>/dev/null || true
  launchctl bootstrap "gui/$uid" "$agents_dir/com.dabaibudai.whisper-daily.scheduler.plist"
  launchctl bootstrap "gui/$uid" "$agents_dir/com.dabaibudai.whisper-daily.status.plist"
  launchctl kickstart "gui/$uid/com.dabaibudai.whisper-daily.scheduler"
  launchctl kickstart "gui/$uid/com.dabaibudai.whisper-daily.status"
fi

if [ "$test_mode" != "1" ]; then
  brew_prefix=$(brew --prefix)
  if [ -w "$brew_prefix/bin" ]; then
    ln -sf "$runtime_root/scripts/whisper-daily" "$brew_prefix/bin/whisper-daily"
  fi
fi
if [ ! -e "$HOME/WhisperDaily Records" ]; then
  ln -s "$runtime_root/records" "$HOME/WhisperDaily Records"
fi

echo "[6/6] Verifying"
if [ "$test_mode" != "1" ]; then
  /bin/zsh "$runtime_root/scripts/doctor.sh"
else
  test -x "$runtime_root/runtime/run.zsh"
  test -x "$runtime_root/bin/zh-simplify"
  test -x "$app_path/Contents/MacOS/WhisperDaily"
  echo "      Test installation verified"
fi
echo ""
echo "Installed. Schedule: 09:00-12:00 and 13:30-18:00 every day."
echo "Run 'whisper-daily start' once to test now and grant microphone access."
echo "Edit the schedule with 'whisper-daily config'."
