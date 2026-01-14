#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

source work/config

TMPDIR="$(mktemp -d)"
echo "Mounting vendor to $TMPDIR..."
mount work/vendor.img $TMPDIR

if [[ "$1" == "--with-debug" ]]; then
  echo "Debugging enabled"
  echo "Patching init.qcom.rc..."
  cat patch/log_from_init.rc >> $TMPDIR/etc/init/hw/init.qcom.rc
  echo "Patching sepolicy..."
  rm -f $TMPDIR/etc/selinux/precompiled_sepolicy
  cat patch/log_from_init.cil >> $TMPDIR/etc/selinux/vendor_sepolicy.cil
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

echo "mkdir $TMPDIR/internalcachesothatwecanbootfromsdcard..."
mkdir $TMPDIR/internalcachesothatwecanbootfromsdcard | true

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

echo "Unmounting..."
umount $TMPDIR
rm -r $TMPDIR

echo "Done."
