#!/bin/zsh
set -u

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

root_dir="${LISTENOTE_DAILY_ROOT:-$HOME/Library/Application Support/Listenote Daily}"
stream_bin="$root_dir/vendor/whisper-stream/whisper-stream"
record_dir="$root_dir/records/transcripts"
log_dir="$root_dir/records/logs"
pid_file="$root_dir/records/listenote-daily.pid"
simplifier="$root_dir/bin/zh-simplify"
transcript_filter="$root_dir/runtime/filter-transcript.zsh"
model_size="${MODEL_SIZE:-large-v3-turbo}"
language="${LANGUAGE:-zh}"
model_path="$root_dir/models/ggml-$model_size.bin"
vad_model_path="$root_dir/models/ggml-silero-v5.1.2.bin"
asr_backend="${ASR_BACKEND:-whisper}"
qwen_server_pid=""

mkdir -p "$record_dir" "$log_dir"
print -r -- "$$" > "$pid_file"

cleanup() {
  pkill -TERM -P $$ 2>/dev/null || true
  if [ -n "$qwen_server_pid" ]; then
    kill "$qwen_server_pid" 2>/dev/null || true
    wait "$qwen_server_pid" 2>/dev/null || true
  fi
  rm -f "$pid_file"
}
trap cleanup EXIT INT TERM HUP

if [ "$asr_backend" = "qwen" ]; then
  qwen_python="${QWEN_PYTHON:-$root_dir/qwen-venv/bin/python}"
  qwen_hf_home="${QWEN_HF_HOME:-$root_dir/qwen-cache}"
  qwen_model="${QWEN_MODEL:-moona3k/mlx-qwen3-asr-0.6b-8bit}"
  qwen_port="${QWEN_PORT:-18765}"
  if [ ! -x "$qwen_python" ]; then
    print -r -- "Qwen Python missing: $qwen_python" >> "$log_dir/runtime-$(date +%Y-%m-%d).log"
    exit 1
  fi
  export HF_HOME="$qwen_hf_home" HF_HUB_OFFLINE=1 QWEN_MODEL="$qwen_model" QWEN_PORT="$qwen_port"
  "$qwen_python" "$root_dir/runtime/qwen-server.py" >> "$log_dir/qwen-server.log" 2>&1 &
  qwen_server_pid=$!
  ready=0
  for attempt in {1..90}; do
    if curl -fsS --max-time 1 "http://127.0.0.1:$qwen_port/health" 2>/dev/null | jq -e --arg model "$qwen_model" '.status == "ok" and .model == $model' >/dev/null 2>&1; then
      ready=1
      break
    fi
    if ! kill -0 "$qwen_server_pid" 2>/dev/null; then break; fi
    sleep 1
  done
  if [ "$ready" != "1" ]; then
    print -r -- "Qwen server did not become ready; see qwen-server.log" >> "$log_dir/runtime-$(date +%Y-%m-%d).log"
    exit 1
  fi
  stream_args=(--backend api --api-url "http://127.0.0.1:$qwen_port/v1/audio/transcriptions" --token listenote-local --model "$qwen_model" --language "$language")
elif [ "$asr_backend" = "whisper" ]; then
  stream_args=(--backend local --language "$language" --model-path "$model_path" --vad --vad-model-path "$vad_model_path")
else
  print -r -- "Unsupported ASR_BACKEND: $asr_backend" >> "$log_dir/runtime-$(date +%Y-%m-%d).log"
  exit 1
fi

"$stream_bin" "${stream_args[@]}" --silence 1.5 --duration 30 --jsonl \
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
  if [ -f "$transcript_filter" ]; then
    filtered_text=$(print -rn -- "$text" | /bin/zsh "$transcript_filter")
    if [ -n "$text" ] && [ -z "$filtered_text" ]; then
      print -r -- "Filtered likely Whisper hallucination at $start_local" >> "$log_dir/runtime-$(date +%Y-%m-%d).log"
      continue
    fi
    text="$filtered_text"
  fi

  print -r -- "## $start_time–$end_time" >> "$record_file"
  print -r -- "" >> "$record_file"
  print -r -- "$text" >> "$record_file"
  print -r -- "" >> "$record_file"
  print -r -- "<!-- start: $start_local | end: $end_local | duration: $duration | model: $model -->" >> "$record_file"
  print -r -- "" >> "$record_file"
done
