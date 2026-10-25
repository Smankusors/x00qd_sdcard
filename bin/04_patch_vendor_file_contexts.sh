#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

source work/config
source bin/lib/vendor_image.sh
source bin/lib/boot_image.sh
trap cleanup_vendor_image EXIT
mount_vendor_image

patch_vendor_file_contexts() {
  local contexts_file="$1"
  local block_device_root="${MICROSD_DEVICE_PATH%/}/by-name"

  echo "Patching $contexts_file..."
  sed -i 's|^/dev/block/mmcblk1[[:space:]]\+u:object_r:sd_device:s0$|/dev/block/mmcblk1 u:object_r:root_block_device:s0|' "$contexts_file"
  sed -i '/^\/dev\/block\/mmcblk1p1[[:space:]]/d' "$contexts_file"
  printf '%s u:object_r:system_block_device:s0\n' "$block_device_root/microsd_system" >> "$contexts_file"
  printf '%s u:object_r:cache_block_device:s0\n' "$block_device_root/microsd_cache" >> "$contexts_file"
  printf '%s u:object_r:userdata_block_device:s0\n' "$block_device_root/microsd_userdata" >> "$contexts_file"
}

VENDORFILECONTEXTSFILE="$(find_vendor_path etc/selinux/vendor_file_contexts || true)"
if [[ -n "$VENDORFILECONTEXTSFILE" && ! -f "$VENDORFILECONTEXTSFILE" ]]; then
  echo "Error: expected vendor_file_contexts to be a file, but found a directory: $VENDORFILECONTEXTSFILE." >&2
  exit 1
fi

RAMDISK_ROOT="Android_boot_image_editor/build/unzip_boot/root"
RAMDISK_CONTEXTS_FILE="$RAMDISK_ROOT/vendor_file_contexts"
if [[ -n "$VENDORFILECONTEXTSFILE" ]]; then
  VENDORFILECONTEXTS_BACKUP="${VENDORFILECONTEXTSFILE}.bak"
  cp "$VENDORFILECONTEXTSFILE" "$VENDORFILECONTEXTS_BACKUP"
  chcon --reference="$VENDORFILECONTEXTSFILE" "$VENDORFILECONTEXTS_BACKUP"
  patch_vendor_file_contexts "$VENDORFILECONTEXTSFILE"
  chcon --reference="$VENDORFILECONTEXTS_BACKUP" "$VENDORFILECONTEXTSFILE"
  rm "$VENDORFILECONTEXTS_BACKUP"
elif [[ -f "$RAMDISK_CONTEXTS_FILE" ]]; then
  patch_vendor_file_contexts "$RAMDISK_CONTEXTS_FILE"
  repack_boot_image
else
  echo "Error: vendor_file_contexts not found in $VENDOR_IMAGE or $RAMDISK_CONTEXTS_FILE."
  exit 1
fi

echo "Done."
