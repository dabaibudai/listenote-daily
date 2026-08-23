#!/bin/zsh
set -u

root_dir="$HOME/Library/Application Support/WhisperDaily"
config_file="$root_dir/config/schedule.conf"
label="com.dabaibudai.whisper-daily.runtime"
pid_file="$root_dir/records/whisper-daily.pid"
override_file="$root_dir/config/manual.override"
pause_file="$root_dir/config/pause.override"
log_dir="$root_dir/records/logs"

[ -f "$config_file" ] || exit 0
source "$config_file"

job_running() {
  local pid=""
  [ -f "$pid_file" ] && pid=$(sed -n '1p' "$pid_file")
  [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null
}

start_job() {
  job_running && return 0
  launchctl remove "$label" 2>/dev/null || true
  launchctl submit -l "$label" \
    -o "$log_dir/launchd-runtime.out" \
    -e "$log_dir/launchd-runtime.err" \
    -- /usr/bin/env \
    "WHISPER_DAILY_ROOT=$root_dir" \
    "MODEL_SIZE=${MODEL_SIZE:-medium}" \
    "LANGUAGE=${LANGUAGE:-zh}" \
    /bin/zsh "$root_dir/runtime/run.zsh"
}

stop_job() {
  job_running || return 0
  launchctl remove "$label" 2>/dev/null || true
}

scheduled_now=0
if [ "${ENABLED:-0}" = "1" ]; then
  day=$(date +%u)
  now=$(date +%H:%M)
  if [[ ",${DAYS:-}," == *",$day,"* ]]; then
    for window in ${(s:,:)WINDOWS}; do
      start="${window%-*}"
      end="${window#*-}"
      if [[ ( "$now" == "$start" || "$now" > "$start" ) && "$now" < "$end" ]]; then
        scheduled_now=1
        break
      fi
    done
  fi
fi

should_run="$scheduled_now"
if [ -f "$override_file" ]; then
  should_run=1
elif [ -f "$pause_file" ]; then
  should_run=0
  if [ "$scheduled_now" = "0" ]; then
    rm -f "$pause_file"
  fi
fi

if [ "${WHISPER_DAILY_DRY_RUN:-0}" = "1" ]; then
  echo "$should_run"
  exit 0
fi

mkdir -p "$log_dir"
if [ "$should_run" = "1" ]; then
  start_job
else
  stop_job
fi
