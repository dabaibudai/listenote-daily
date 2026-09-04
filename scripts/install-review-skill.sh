#!/bin/zsh
set -eu

source_root="${0:A:h:h}/skills/listenote-daily-review"
destination="${CODEX_HOME:-$HOME/.codex}/skills/listenote-daily-review"
if [ "$#" -ne 0 ]; then
  if [ "$#" -ne 2 ] || [ "$1" != "--target" ]; then
    echo "Usage: install-review-skill.sh [--target /path/to/listenote-daily-review]" >&2
    exit 2
  fi
  destination="$2"
fi
test -f "$source_root/SKILL.md"
if [ -e "$destination" ] || [ -L "$destination" ]; then
  echo "Existing skill preserved: $destination"
  echo "Bundled version available at: $source_root"
  exit 0
fi
mkdir -p "${destination:h}"
ditto "$source_root" "$destination"
echo "Review skill installed: $destination"
echo 'In Codex: Use $listenote-daily-review to review yesterday.'
