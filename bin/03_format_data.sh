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

source work/config
case "${VENDOR_LAYOUT:-}" in
  separate)
    CACHE_PARTITION="${DEVICE}4"
    USERDATA_PARTITION="${DEVICE}5"
    ;;
  system)
    CACHE_PARTITION="${DEVICE}3"
    USERDATA_PARTITION="${DEVICE}4"
    ;;
esac

KERNEL_CONFIG_FILE="Android_boot_image_editor/build/unzip_boot/kernel_configs.txt"
KERNEL_IMAGE_FILE="Android_boot_image_editor/build/unzip_boot/kernel"
if [[ -f "$KERNEL_CONFIG_FILE" && -f "$KERNEL_IMAGE_FILE" ]]; then
  if grep -q "CONFIG_FS_VERITY=y" "$KERNEL_CONFIG_FILE"; then
    SUPPORTS_VERITY=true
  else
    SUPPORTS_VERITY=false
  fi
  echo "Kernel supports verity: $SUPPORTS_VERITY"

  # CONFIG_QUOTA enables generic quotas, not necessarily ext4 project quotas.
  # Only add project when its handler is present in the compiled kernel image.
  SUPPORTS_PROJECT_QUOTA=false
  PROJECT_QUOTA_STATUS="unknown; omitting project feature"
  KERNEL_MIME_TYPE=$(file -b --mime-type "$KERNEL_IMAGE_FILE")
  KERNEL_PROJECT_SYMBOL=$(
    case "$KERNEL_MIME_TYPE" in
      application/gzip) gzip -cd "$KERNEL_IMAGE_FILE" 2>/dev/null ;;
      application/x-lz4|application/lz4) lz4 -dc "$KERNEL_IMAGE_FILE" 2>/dev/null ;;
      application/x-xz) xz -dc "$KERNEL_IMAGE_FILE" 2>/dev/null ;;
      *) cat "$KERNEL_IMAGE_FILE" ;;
    esac | grep -a -o -F 'ext4_ioctl_setproject' || true
  )
  if [[ -n "$KERNEL_PROJECT_SYMBOL" ]]; then
    SUPPORTS_PROJECT_QUOTA=true
    PROJECT_QUOTA_STATUS="detected in kernel symbols"
  fi
  echo "Ext4 project quota support: $PROJECT_QUOTA_STATUS"
else
  echo "Error: Kernel config or image is missing ($KERNEL_CONFIG_FILE, $KERNEL_IMAGE_FILE)."
  exit 1
fi

read -rp "Filesystem for cache ($CACHE_PARTITION) [ext4/f2fs]: " CACHE_FS
read -rp "Filesystem for userdata ($USERDATA_PARTITION) [ext4/f2fs]: " USERDATA_FS

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

echo "Formatting cache partition ($CACHE_PARTITION) as $CACHE_FS..."
if [[ "$CACHE_FS" == "f2fs" ]]; then
  mkfs.f2fs -f "$CACHE_PARTITION"
elif [[ "$CACHE_FS" == "ext4" ]]; then
  mkfs.ext4 -F -O dir_nlink,extra_isize,has_journal,extent,uninit_bg,^metadata_csum_seed,^orphan_file "$CACHE_PARTITION"
fi

echo "Formatting userdata partition ($USERDATA_PARTITION) as $USERDATA_FS..."
if [[ "$USERDATA_FS" == "f2fs" ]]; then
  if [[ "$SUPPORTS_VERITY" == true ]]; then
    mkfs.f2fs -f -O encrypt,verity "$USERDATA_PARTITION"
  else
    mkfs.f2fs -f -O encrypt "$USERDATA_PARTITION"
  fi
elif [[ "$USERDATA_FS" == "ext4" ]]; then
  EXT4_USERDATA_FEATURES="64bit,dir_nlink,encrypt,extent,extra_isize,has_journal,metadata_csum,quota,^metadata_csum_seed,^orphan_file"
  if [[ "$SUPPORTS_PROJECT_QUOTA" == true ]]; then
    EXT4_USERDATA_FEATURES+=",project"
  fi
  if [[ "$SUPPORTS_VERITY" == true ]]; then
    EXT4_USERDATA_FEATURES+=",verity"
  fi
  mkfs.ext4 -F -O "$EXT4_USERDATA_FEATURES" "$USERDATA_PARTITION"
fi

echo "Partitioning and formatting completed successfully on $DEVICE."
