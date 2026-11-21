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

source work/config
source bin/lib/vendor_fstab.sh
source bin/lib/boot_verity.sh
source bin/lib/legacy_verity.sh

SYSTEM_BLOCK_DEVICE="${MICROSD_DEVICE_PATH%/}/by-name/microsd_system"
BOOT_IMAGE_DIR="Android_boot_image_editor/build/unzip_boot"
SYSTEM_FSMGR_FLAGS="$(get_system_fsmgr_flags "$BOOT_IMAGE_DIR")"
SYSTEM_VERITY_MODE="$(system_verity_mode_from_flags "$SYSTEM_FSMGR_FLAGS")"
SYSTEM_IMAGE_TO_WRITE="work/system.img"
echo "System fsmgr_flags: ${SYSTEM_FSMGR_FLAGS:-<empty>}"

if [[ "$SYSTEM_VERITY_MODE" == avb ]]; then
  echo "Error: system uses AVB; the legacy dm-verity image builder cannot create an AVB image." >&2
  exit 1
elif [[ "$SYSTEM_VERITY_MODE" == verifyatboot ]]; then
  echo "Error: system uses verifyatboot, which is not supported by the legacy dm-verity image builder." >&2
  exit 1
elif [[ "$SYSTEM_VERITY_MODE" == legacy ]]; then
  if [[ ! -f "$LEGACY_DM_VERITY_PRIVATE_KEY" || ! -f "$LEGACY_DM_VERITY_KEY_BLOB" ||
    ! -f "$BOOT_IMAGE_DIR/root/verity_key" ]] ||
    ! cmp -s -- "$LEGACY_DM_VERITY_KEY_BLOB" "$BOOT_IMAGE_DIR/root/verity_key"; then
    echo "Error: legacy dm-verity keys are missing or do not match the prepared boot files; run step 7 first." >&2
    exit 1
  fi
  echo "Legacy dm-verity is enabled for system; building the verity image..."
  python3 bin/build_legacy_verity_image.py \
    --image work/system.img \
    --output work/system.verity.img \
    --partition-size "$BOARD_SYSTEMIMAGE_PARTITION_SIZE" \
    --block-device "$SYSTEM_BLOCK_DEVICE" \
    --signing-key "$LEGACY_DM_VERITY_PRIVATE_KEY"
  SYSTEM_IMAGE_TO_WRITE="work/system.verity.img"
else
  echo "No verity mode detected for system; skipping verity image generation."
fi

echo "Writing ${SYSTEM_IMAGE_TO_WRITE} to ${DEVICE}2"
pv "$SYSTEM_IMAGE_TO_WRITE" | dd of="$DEVICE"2 iflag=fullblock oflag=direct bs=4M

if [[ "$VENDOR_LAYOUT" == separate ]]; then
  echo "Writing vendor to ${DEVICE}3"
  pv work/vendor.img | dd of=${DEVICE}3 iflag=fullblock oflag=direct bs=4M
else
  echo "No microSD vendor image to write for VENDOR_LAYOUT=$VENDOR_LAYOUT."
fi

echo "Done."
