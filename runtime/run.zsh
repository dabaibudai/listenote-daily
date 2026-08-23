#!/bin/zsh
set -u

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

root_dir="${WHISPER_DAILY_ROOT:-$HOME/Library/Application Support/WhisperDaily}"
stream_bin="$root_dir/vendor/whisper-stream/whisper-stream"
record_dir="$root_dir/records/transcripts"
log_dir="$root_dir/records/logs"
pid_file="$root_dir/records/whisper-daily.pid"
simplifier="$root_dir/bin/zh-simplify"
model_size="${MODEL_SIZE:-medium}"
language="${LANGUAGE:-zh}"
model_path="$root_dir/models/ggml-$model_size.bin"
vad_model_path="$root_dir/models/ggml-silero-v5.1.2.bin"

mkdir -p "$record_dir" "$log_dir"
print -r -- "$$" > "$pid_file"

cleanup() {
  pkill -TERM -P $$ 2>/dev/null || true
  rm -f "$pid_file"
}
trap cleanup EXIT INT TERM HUP

"$stream_bin" \
  --backend local \
  --language "$language" \
  --model-path "$model_path" \
  --vad \
  --vad-model-path "$vad_model_path" \
  --silence 1.5 \
  --duration 30 \
  --jsonl \
  2>> "$log_dir/runtime-$(date +%Y-%m-%d).log" |
while IFS= read -r line; do
  if ! print -r -- "$line" | jq -e . >/dev/null 2>&1; then
    print -r -- "Invalid JSONL: $line" >> "$log_dir/runtime-$(date +%Y-%m-%d).log"
    continue
  fi

  record_date=$(print -r -- "$line" | jq -r '.local_date // (.start_at[0:10]) // (.ts[0:10])')
  [[ "$record_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || record_date=$(date +%Y-%m-%d)
  record_file="$record_dir/$record_date.md"
  if [ ! -f "$record_file" ]; then
    print -r -- "# $record_date" > "$record_file"
    print -r -- "" >> "$record_file"
  fi

  start_local=$(print -r -- "$line" | jq -r '.start_local // .start_at // ""')
  end_local=$(print -r -- "$line" | jq -r '.end_local // .end_at // ""')
  start_time=$(print -r -- "$start_local" | sed -E 's/^.*T([0-9]{2}:[0-9]{2}:[0-9]{2}).*$/\1/')
  end_time=$(print -r -- "$end_local" | sed -E 's/^.*T([0-9]{2}:[0-9]{2}:[0-9]{2}).*$/\1/')
  duration=$(print -r -- "$line" | jq -r '.duration // ""')
  model=$(print -r -- "$line" | jq -r '.model // ""')
  text=$(print -r -- "$line" | jq -r '.text // ""')
  [ -x "$simplifier" ] && text=$(print -rn -- "$text" | "$simplifier")

  print -r -- "## $start_time–$end_time" >> "$record_file"
  print -r -- "" >> "$record_file"
  print -r -- "$text" >> "$record_file"
  print -r -- "" >> "$record_file"
  print -r -- "<!-- start: $start_local | end: $end_local | duration: $duration | model: $model -->" >> "$record_file"
  print -r -- "" >> "$record_file"
done
