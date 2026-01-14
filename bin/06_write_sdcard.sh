#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

# Check if a device was provided as an argument
if [[ -z "$1" ]]; then
  echo "Usage: $0 /dev/sdX"
  exit 1
fi

DEVICE="$1"

if [[ ! -b "$DEVICE" ]]; then
  echo "Error: $DEVICE is not a valid block device."
  exit 1
fi

echo "Writing system to ${DEVICE}2"
pv work/system.img | dd of=${DEVICE}2 iflag=fullblock oflag=direct bs=4M

echo "Writing vendor to ${DEVICE}3"
pv work/vendor.img | dd of=${DEVICE}3 iflag=fullblock oflag=direct bs=4M

echo "Done."
