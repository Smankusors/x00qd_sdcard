#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

# Check if device and filesystem are provided as an argument
if [[ -z "$1" || -z "$2" ]]; then
  echo "Usage: $0 /dev/sdX ext4/f2fs"
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

read -p "Are you sure you want to format $DEVICE? This will erase cache and user data! (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Operation canceled."
  exit 0
fi

DEVICE="$1"
FS="$2"

if [[ ! -b "$DEVICE" ]]; then
  echo "Error: $DEVICE is not a valid block device."
  exit 1
fi

if [[ "$FS" != "ext4" && "$FS" != "f2fs" ]]; then
  echo "Error: Invalid filesystem specified. Please choose ext4 or f2fs."
  exit 1
fi

echo "Formatting partitions..."
if [[ "$FS" == "f2fs" ]]; then
  mkfs.f2fs -f "${DEVICE}3"
  if [[ "$SUPPORTS_VERITY" == true ]]; then
    mkfs.f2fs -f -O encrypt,verity "${DEVICE}4"
  else
    mkfs.f2fs -f -O encrypt "${DEVICE}4"
  fi
elif [[ "$FS" == "ext4" ]]; then
  mkfs.ext4 -F -O dir_nlink,extra_isize,has_journal,extent,uninit_bg "${DEVICE}3"
  if [[ "$SUPPORTS_VERITY" == true ]]; then
    mkfs.ext4 -F -O 64bit,dir_nlink,encrypt,extent,extra_isize,has_journal,metadata_csum,project,quota,verity "${DEVICE}4"
  else
    mkfs.ext4 -F -O 64bit,dir_nlink,encrypt,extent,extra_isize,has_journal,metadata_csum,project,quota "${DEVICE}4"
  fi
fi

echo "Partitioning and formatting completed successfully on $DEVICE."
