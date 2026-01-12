#!/bin/bash

# Check if a script name is provided
if [ -z "$1" ]; then
  echo "No script name provided."
  echo "Available scripts in the bin folder:"

  # Check if the bin folder exists and list scripts
  if [ -d "./bin" ]; then
    ls -1 "./bin"
  else
    echo "Error: '$BIN_FOLDER' folder does not exist or cannot be accessed."
  fi

  exit 1
fi

docker compose run --rm x00qd_sdcard $@
