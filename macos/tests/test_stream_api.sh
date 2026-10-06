#!/bin/bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
stream="$script_dir/../vendor/whisper-stream/whisper-stream"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

sox -n -r 44100 -c 1 "$test_dir/valid.mp3" trim 0 1
WHISPER_STREAM_LIB=1 source "$stream"
BACKEND=api
AUDIO_FILE="$test_dir/valid.mp3"
API_URL=http://127.0.0.1:1/v1/audio/transcriptions
MODEL=test-model
TOKEN=""
JSONL_MODE=true
STDOUT_MODE=true
WORK_DIR="$test_dir"

curl() {
  printf '%s\n200' "$MOCK_RESPONSE"
}

MOCK_RESPONSE='{"text":"正常转录"}'
result=$(convert_audio_to_text "$AUDIO_FILE")
printf '%s' "$result" | jq -e '
  .text == "正常转录" and .duration > 0 and
  (.start_at | length > 0) and (.end_at | length > 0) and
  (.start_local | length > 0) and (.local_date | length > 0)
' >/dev/null

MOCK_RESPONSE='{"text":""}'
result=$(convert_audio_to_text "$AUDIO_FILE")
test -z "$result"

MOCK_RESPONSE='{"unexpected":"payload"}'
if convert_audio_to_text "$AUDIO_FILE" > "$test_dir/invalid-output" 2>/dev/null; then
  echo "Malformed API response was accepted" >&2
  exit 1
fi
test ! -s "$test_dir/invalid-output"

AUDIO_FILE=""
sox -n -r 44100 -c 1 "$test_dir/empty.mp3" trim 0 0
result=$(convert_audio_to_text "$test_dir/empty.mp3")
test -z "$result"
test ! -e "$test_dir/empty.mp3"
