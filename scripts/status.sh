#!/bin/zsh
set -u
root_dir="$HOME/Library/Application Support/Listenote Daily"
pid_file="$root_dir/records/listenote-daily.pid"
config_file="$root_dir/config/schedule.conf"

if [ -f "$pid_file" ]; then
  pid=$(sed -n '1p' "$pid_file")
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    echo "Session: running (PID $pid)"
  else
    echo "Session: stale PID"
  fi
else
  echo "Session: stopped"
fi

if [ -f "$config_file" ]; then
  source "$config_file"
  echo "Schedule: enabled=${ENABLED:-0}, days=${DAYS:-}, windows=${WINDOWS:-}"
fi
echo "Notes: $root_dir/records/transcripts"
