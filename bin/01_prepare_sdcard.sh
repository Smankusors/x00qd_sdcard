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

echo "Current partition table for $DEVICE:"
parted "$DEVICE" print

read -p "Are you sure you want to partition and format $DEVICE? This will erase all data! (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Operation canceled."
  exit 0
fi

echo "Creating partitions on $DEVICE..."
parted "$DEVICE" --script \
  mklabel gpt \
  mkpart microsd_system ext4 2048s 7342079s \
  mkpart microsd_vendor ext4 7342080s 9439231s \
  mkpart microsd_cache ext4 9439232s 9701375s \
  mkpart microsd_userdata ext4 9701376s 100%

echo "Formatting partitions..."
mkfs.ext4 "${DEVICE}3"
mkfs.ext4 -O encrypt "${DEVICE}4"

echo "Partitioning and formatting completed successfully on $DEVICE."
