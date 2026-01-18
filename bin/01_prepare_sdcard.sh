#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

if [[ -z "$1" ]]; then
  echo "Usage: $0 /dev/sdX"
  exit 1
fi

DEVICE="$1"

if [[ ! -b "$DEVICE" ]]; then
  echo "Error: $DEVICE is not a valid block device."
  exit 1
fi

source work/config

echo "Current partition table for $DEVICE:"
parted "$DEVICE" print

read -p "Are you sure you want to partition $DEVICE? This will erase all data! (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Operation canceled."
  exit 0
fi

BOOT_PARTITION_START=1048576 # aligned to 2048s for best performance
SYSTEM_PARTITION_START=$(( BOOT_PARTITION_START + BOARD_BOOTIMAGE_PARTITION_SIZE ))
VENDOR_PARTITION_START=$(( SYSTEM_PARTITION_START + BOARD_SYSTEMIMAGE_PARTITION_SIZE ))
CACHE_PARTITION_START=$(( VENDOR_PARTITION_START + BOARD_VENDORIMAGE_PARTITION_SIZE ))
USERDATA_PARTITION_START=$(( CACHE_PARTITION_START + BOARD_CACHEIMAGE_PARTITION_SIZE ))

echo "Creating partitions on $DEVICE..."
set -x
parted "$DEVICE" --script \
  mklabel gpt \
  mkpart microsd_boot ext4 ${BOOT_PARTITION_START}B $(( SYSTEM_PARTITION_START - 1 ))B \
  mkpart microsd_system ext4 ${SYSTEM_PARTITION_START}B $(( VENDOR_PARTITION_START - 1 ))B \
  mkpart microsd_vendor ext4 ${VENDOR_PARTITION_START}B $(( CACHE_PARTITION_START - 1 ))B \
  mkpart microsd_cache ext4 ${CACHE_PARTITION_START}B $(( USERDATA_PARTITION_START - 1 ))B \
  mkpart microsd_userdata ext4 ${USERDATA_PARTITION_START}B 100%
set +x

echo "Formatting boot partition (${DEVICE}1) as ext4..."
mkfs.ext4 -F -O dir_nlink,extra_isize,has_journal,extent,uninit_bg "${DEVICE}1"

echo "Done."
