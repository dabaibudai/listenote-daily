#!/bin/zsh
set -eu
record_dir="$HOME/Library/Application Support/Listenote Daily/records/transcripts"
query="${1:-}"
record_date="${2:-}"

if [ -z "$query" ]; then
  echo "Usage: $0 <keyword> [YYYY-MM-DD]" >&2
  exit 2
fi

if [ -n "$record_date" ]; then
  files=("$record_dir/$record_date.md")
else
  files=("$record_dir"/*.md(N))
fi

if [ ${#files[@]} -eq 0 ] || [ ! -f "${files[1]}" ]; then
  echo "No notes found." >&2
  exit 1
fi
rg -n -C 2 --fixed-strings -- "$query" "${files[@]}"
