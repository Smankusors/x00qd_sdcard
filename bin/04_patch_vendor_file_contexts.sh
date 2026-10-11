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

if [[ "$VENDOR_LAYOUT" == separate ]]; then
  VENDOR_ROOT="$MOUNT_ROOT"
else
  VENDOR_ROOT=""
  for candidate in "$MOUNT_ROOT/vendor" "$MOUNT_ROOT/system/vendor" "$MOUNT_ROOT"; do
    if [[ -f "$candidate/etc/fstab.qcom" ]]; then
      VENDOR_ROOT="$candidate"
      break
    fi
  done
  if [[ -z "$VENDOR_ROOT" ]]; then
    echo "Error: system.img has no recognizable vendor tree with fstab.qcom."
    exit 1
  fi
fi

VENDORFILECONTEXTSFILE="$VENDOR_ROOT/etc/selinux/vendor_file_contexts"
if [[ ! -f "$VENDORFILECONTEXTSFILE" ]]; then
  echo "Error: vendor_file_contexts not found in $VENDOR_IMAGE."
  exit 1
fi

echo "Patching vendor_file_contexts..."
cp "$VENDORFILECONTEXTSFILE" "$VENDORFILECONTEXTSFILE.bak"
chcon --reference="$VENDORFILECONTEXTSFILE" "$VENDORFILECONTEXTSFILE.bak"
sed -i 's|^/dev/block/mmcblk1[[:space:]]\+u:object_r:sd_device:s0$|/dev/block/mmcblk1 u:object_r:root_block_device:s0|' "$VENDORFILECONTEXTSFILE"
sed -i '/^\/dev\/block\/mmcblk1p1[[:space:]]/d' "$VENDORFILECONTEXTSFILE"
echo "/dev/block/platform/soc/$MICROSD_ADDR/by-name/microsd_system u:object_r:system_block_device:s0" >> "$VENDORFILECONTEXTSFILE"
echo "/dev/block/platform/soc/$MICROSD_ADDR/by-name/microsd_cache u:object_r:cache_block_device:s0" >> "$VENDORFILECONTEXTSFILE"
echo "/dev/block/platform/soc/$MICROSD_ADDR/by-name/microsd_userdata u:object_r:userdata_block_device:s0" >> "$VENDORFILECONTEXTSFILE"
chcon --reference="$VENDORFILECONTEXTSFILE.bak" "$VENDORFILECONTEXTSFILE"
rm "$VENDORFILECONTEXTSFILE.bak"

echo "Done."
