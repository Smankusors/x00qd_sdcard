#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "No script name provided."
  echo
  echo "Available executable setup steps:"

  shopt -s nullglob
  AVAILABLE_SCRIPTS=(./bin/[0-9][0-9]_*.sh)
  shopt -u nullglob

  for script in "${AVAILABLE_SCRIPTS[@]}"; do
    if [[ -f "$script" && -x "$script" ]]; then
      printf '  %s\n' "${script##*/}"
    fi
  done

  exit 1
fi

docker compose run --rm x00qd_sdcard $@
