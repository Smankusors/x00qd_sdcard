#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

TMPDIR="$(mktemp -d)"
echo "Mounting vendor to $TMPDIR..."
mount work/vendor.img $TMPDIR

echo "Patching..."
cp patch/fstab.qcom $TMPDIR/etc/fstab.qcom
mkdir $TMPDIR/internalcachesothatwecanbootfromsdcard | true
echo "/dev/block/platform/soc/c084000.sdhci/by-name/microsd_userdata u:object_r:userdata_block_device:s0" >> $TMPDIR/etc/selinux/vendor_file_contexts
echo "/dev/block/platform/soc/c084000.sdhci/by-name/microsd_cache u:object_r:cache_block_device:s0" >> $TMPDIR/etc/selinux/vendor_file_contexts

echo "Unmounting..."
umount $TMPDIR
rm -r $TMPDIR

echo "Done."
