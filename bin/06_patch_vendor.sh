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

append_vendor_patch() {
  local destination="$VENDOR_ROOT/$1"
  local canonical

  canonical="$(realpath -e -- "$destination")" || {
    echo "Missing vendor debug destination: $destination" >&2
    return 1
  }
  if [[ "$canonical" != "$destination" || ! -f "$canonical" ]]; then
    echo "Refusing unsafe vendor debug destination: $destination" >&2
    return 1
  fi
  cat -- "$2" >> "$canonical"
}

if [[ "$1" == "--with-debug" ]]; then
  echo "Debugging enabled"
  echo "Patching init.qcom.rc..."
  append_vendor_patch etc/init/hw/init.qcom.rc patch/log_from_init.rc
  echo "Patching sepolicy..."
  append_vendor_patch etc/selinux/vendor_sepolicy.cil patch/log_from_init.cil
  rm -f "$VENDOR_ROOT/etc/selinux/precompiled_sepolicy"
fi

echo "Patching fstab.qcom..."
FSTABQCOMFILE="$VENDOR_ROOT/etc/fstab.qcom"
cp $FSTABQCOMFILE $FSTABQCOMFILE.bak
chcon --reference=$FSTABQCOMFILE $FSTABQCOMFILE.bak
sed -i "/$MICROSD_ADDR/d" $FSTABQCOMFILE
sed -i "s/\/dev\/block\/bootdevice\/by-name\/userdata/\/dev\/block\/platform\/soc\/$MICROSD_ADDR\/by-name\/microsd_userdata/g" $FSTABQCOMFILE
sed -i "s/\/dev\/block\/bootdevice\/by-name\/cache/\/dev\/block\/platform\/soc\/$MICROSD_ADDR\/by-name\/microsd_cache/g" $FSTABQCOMFILE
chcon --reference=$FSTABQCOMFILE.bak $FSTABQCOMFILE
rm $FSTABQCOMFILE.bak

echo "Done."
