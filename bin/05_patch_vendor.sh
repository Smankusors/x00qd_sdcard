#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

source work/config

TMPDIR="$(mktemp -d)"
echo "Mounting vendor to $TMPDIR..."
VENDOR_MOUNTED=0
cleanup() {
  if [[ "$VENDOR_MOUNTED" -eq 1 ]]; then
    echo "Unmounting..."
    umount "$TMPDIR"
    VENDOR_MOUNTED=0
  fi
  rmdir "$TMPDIR" 2>/dev/null || true
}
trap cleanup EXIT
mount work/vendor.img "$TMPDIR"
VENDOR_MOUNTED=1
MOUNT_ROOT="$(realpath -e -- "$TMPDIR")"

append_vendor_patch() {
  local destination="$MOUNT_ROOT/$1"
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
  rm -f $TMPDIR/etc/selinux/precompiled_sepolicy
fi

echo "Patching fstab.qcom..."
FSTABQCOMFILE=$TMPDIR/etc/fstab.qcom
cp $FSTABQCOMFILE $FSTABQCOMFILE.bak
chcon --reference=$FSTABQCOMFILE $FSTABQCOMFILE.bak
sed -i "/$MICROSD_ADDR/d" $FSTABQCOMFILE
sed -i "s/\/dev\/block\/bootdevice\/by-name\/userdata/\/dev\/block\/platform\/soc\/$MICROSD_ADDR\/by-name\/microsd_userdata/g" $FSTABQCOMFILE
sed -i "s/\/dev\/block\/bootdevice\/by-name\/cache/\/dev\/block\/platform\/soc\/$MICROSD_ADDR\/by-name\/microsd_cache/g" $FSTABQCOMFILE
chcon --reference=$FSTABQCOMFILE.bak $FSTABQCOMFILE
rm $FSTABQCOMFILE.bak

echo "Patching vendor_file_contexts..."
VENDORFILECONTEXTSFILE=$TMPDIR/etc/selinux/vendor_file_contexts
cp $VENDORFILECONTEXTSFILE $VENDORFILECONTEXTSFILE.bak
chcon --reference=$VENDORFILECONTEXTSFILE $VENDORFILECONTEXTSFILE.bak
sed -i 's|^/dev/block/mmcblk1[[:space:]]\+u:object_r:sd_device:s0$|/dev/block/mmcblk1 u:object_r:root_block_device:s0|' $VENDORFILECONTEXTSFILE
sed -i '/^\/dev\/block\/mmcblk1p1[[:space:]]/d' $VENDORFILECONTEXTSFILE
echo "/dev/block/platform/soc/$MICROSD_ADDR/by-name/microsd_system u:object_r:system_block_device:s0" >> $VENDORFILECONTEXTSFILE
echo "/dev/block/platform/soc/$MICROSD_ADDR/by-name/microsd_cache u:object_r:cache_block_device:s0" >> $VENDORFILECONTEXTSFILE
echo "/dev/block/platform/soc/$MICROSD_ADDR/by-name/microsd_userdata u:object_r:userdata_block_device:s0" >> $VENDORFILECONTEXTSFILE
chcon --reference=$VENDORFILECONTEXTSFILE.bak $VENDORFILECONTEXTSFILE
rm $VENDORFILECONTEXTSFILE.bak

echo "Done."
