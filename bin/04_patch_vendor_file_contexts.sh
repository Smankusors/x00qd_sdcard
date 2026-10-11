#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

source work/config

case "${VENDOR_LAYOUT:-}" in
  separate)
    VENDOR_IMAGE="work/vendor.img"
    ;;
  system)
    VENDOR_IMAGE="work/system.img"
    ;;
esac

TMPDIR="$(mktemp -d)"
echo "Mounting $VENDOR_IMAGE to $TMPDIR..."
IMAGE_MOUNTED=0
cleanup() {
  if [[ "$IMAGE_MOUNTED" -eq 1 ]]; then
    echo "Unmounting..."
    umount "$TMPDIR"
    IMAGE_MOUNTED=0
  fi
  rmdir "$TMPDIR" 2>/dev/null || true
}
trap cleanup EXIT
mount "$VENDOR_IMAGE" "$TMPDIR"
IMAGE_MOUNTED=1
MOUNT_ROOT="$(realpath -e -- "$TMPDIR")"

patch_vendor_file_contexts() {
  local contexts_file="$1"

  echo "Patching $contexts_file..."
  sed -i 's|^/dev/block/mmcblk1[[:space:]]\+u:object_r:sd_device:s0$|/dev/block/mmcblk1 u:object_r:root_block_device:s0|' "$contexts_file"
  sed -i '/^\/dev\/block\/mmcblk1p1[[:space:]]/d' "$contexts_file"
  echo "/dev/block/platform/soc/$MICROSD_ADDR/by-name/microsd_system u:object_r:system_block_device:s0" >> "$contexts_file"
  echo "/dev/block/platform/soc/$MICROSD_ADDR/by-name/microsd_cache u:object_r:cache_block_device:s0" >> "$contexts_file"
  echo "/dev/block/platform/soc/$MICROSD_ADDR/by-name/microsd_userdata u:object_r:userdata_block_device:s0" >> "$contexts_file"
}

VENDORFILECONTEXTSFILE=""
for candidate in "$MOUNT_ROOT" "$MOUNT_ROOT/vendor" "$MOUNT_ROOT/system/vendor"; do
  if [[ -f "$candidate/etc/selinux/vendor_file_contexts" ]]; then
    VENDORFILECONTEXTSFILE="$candidate/etc/selinux/vendor_file_contexts"
    break
  fi
done

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
  echo "Repacking boot ramdisk..."
  cp work/boot.img Android_boot_image_editor/boot.img
  ./Android_boot_image_editor/gradlew -p Android_boot_image_editor pack
else
  echo "Error: vendor_file_contexts not found in $VENDOR_IMAGE or $RAMDISK_CONTEXTS_FILE."
  exit 1
fi

echo "Done."
