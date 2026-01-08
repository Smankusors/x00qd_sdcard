#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

TMPDIR="$(mktemp -d)"
echo "Mounting vendor to $TMPDIR..."
mount work/vendor.img $TMPDIR

if [[ "$1" == "--with-debug" ]]; then
  echo "Debugging enabled, patching init.qcom.rc..."
  cat patch/log_from_init.rc >> $TMPDIR/etc/init/hw/init.qcom.rc
fi

echo "Patching fstab.qcom..."
cp $TMPDIR/etc/fstab.qcom $TMPDIR/etc/fstab.qcom.bak
chcon --reference=$TMPDIR/etc/fstab.qcom $TMPDIR/etc/fstab.qcom.bak
sed -i '/c084000.sdhci/d' $TMPDIR/etc/fstab.qcom
sed -i 's/\/dev\/block\/bootdevice\/by-name\/userdata/\/dev\/block\/platform\/soc\/c084000.sdhci\/by-name\/microsd_userdata/g' $TMPDIR/etc/fstab.qcom
sed -i 's/\/dev\/block\/bootdevice\/by-name\/cache/\/dev\/block\/platform\/soc\/c084000.sdhci\/by-name\/microsd_cache/g' $TMPDIR/etc/fstab.qcom
chcon --reference=$TMPDIR/etc/fstab.qcom.bak $TMPDIR/etc/fstab.qcom
rm $TMPDIR/etc/fstab.qcom.bak

echo "mkdir $TMPDIR/internalcachesothatwecanbootfromsdcard..."
mkdir $TMPDIR/internalcachesothatwecanbootfromsdcard | true

echo "Patching vendor_file_contexts..."
echo "/dev/block/platform/soc/c084000.sdhci/by-name/microsd_system u:object_r:system_block_device:s0" >> $TMPDIR/etc/selinux/vendor_file_contexts
echo "/dev/block/platform/soc/c084000.sdhci/by-name/microsd_cache u:object_r:cache_block_device:s0" >> $TMPDIR/etc/selinux/vendor_file_contexts
echo "/dev/block/platform/soc/c084000.sdhci/by-name/microsd_userdata u:object_r:userdata_block_device:s0" >> $TMPDIR/etc/selinux/vendor_file_contexts

echo "Unmounting..."
umount $TMPDIR
rm -r $TMPDIR

echo "Done."
