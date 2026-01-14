#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "No script name provided."
  echo
  echo "Available scripts in the bin folder:"

  ls -1 "./bin"

  exit 1
fi

docker compose run --rm x00qd_sdcard $@
