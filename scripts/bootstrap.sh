#!/bin/bash
set -euo pipefail

# Compatibility entry point retained for existing articles and install commands.
temp_script=$(mktemp)
cleanup() { rm -f "$temp_script"; }
trap cleanup EXIT

curl -L --fail --retry 3 --progress-bar \
  https://raw.githubusercontent.com/dabaibudai/listenote-daily/main/macos/scripts/bootstrap.sh \
  -o "$temp_script"
/bin/bash "$temp_script"
