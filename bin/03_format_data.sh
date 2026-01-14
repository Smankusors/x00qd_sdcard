#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 /dev/sdX"
  exit 1
fi

DEVICE="$1"

if [[ ! -b "$DEVICE" ]]; then
  echo "Error: $DEVICE is not a valid block device."
  exit 1
fi

KERNEL_CONFIG_FILE="Android_boot_image_editor/build/unzip_boot/kernel_configs.txt"
if [[ -f "$KERNEL_CONFIG_FILE" ]]; then
  if grep -q "CONFIG_FS_VERITY=y" "$KERNEL_CONFIG_FILE"; then
    SUPPORTS_VERITY=true
  else
    SUPPORTS_VERITY=false
  fi
  echo "Kernel supports verity: $SUPPORTS_VERITY"
else
  echo "Error: Kernel configuration file not found at $KERNEL_CONFIG_FILE."
  exit 1
fi

read -rp "Filesystem for cache (${DEVICE}3) [ext4/f2fs]: " CACHE_FS
read -rp "Filesystem for userdata (${DEVICE}4) [ext4/f2fs]: " USERDATA_FS

for FS in "$CACHE_FS" "$USERDATA_FS"; do
  if [[ "$FS" != "ext4" && "$FS" != "f2fs" ]]; then
    echo "Error: Invalid filesystem '$FS'. Please choose ext4 or f2fs."
    exit 1
  fi
done

read -p "Are you sure you want to format $DEVICE? This will erase cache and user data! (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Operation canceled."
  exit 0
fi

echo "Formatting cache partition (${DEVICE}3) as $CACHE_FS..."
if [[ "$CACHE_FS" == "f2fs" ]]; then
  mkfs.f2fs -f "${DEVICE}3"
elif [[ "$CACHE_FS" == "ext4" ]]; then
  mkfs.ext4 -F -O dir_nlink,extra_isize,has_journal,extent,uninit_bg "${DEVICE}3"
fi

echo "Formatting userdata partition (${DEVICE}4) as $USERDATA_FS..."
if [[ "$USERDATA_FS" == "f2fs" ]]; then
  if [[ "$SUPPORTS_VERITY" == true ]]; then
    mkfs.f2fs -f -O encrypt,verity "${DEVICE}4"
  else
    mkfs.f2fs -f -O encrypt "${DEVICE}4"
  fi
elif [[ "$USERDATA_FS" == "ext4" ]]; then
  if [[ "$SUPPORTS_VERITY" == true ]]; then
    mkfs.ext4 -F -O 64bit,dir_nlink,encrypt,extent,extra_isize,has_journal,metadata_csum,project,quota,verity "${DEVICE}4"
  else
    mkfs.ext4 -F -O 64bit,dir_nlink,encrypt,extent,extra_isize,has_journal,metadata_csum,project,quota "${DEVICE}4"
  fi
fi

echo "Partitioning and formatting completed successfully on $DEVICE."
