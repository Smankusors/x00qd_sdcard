#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

TMPDIR="$(mktemp -d)"
echo "Mounting vendor to $TMPDIR..."
mount work/vendor.img $TMPDIR

echo "Patching..."
cp patch/fstab.qcom $TMPDIR/etc/fstab.qcom
mkdir $TMPDIR/internalcachesothatwecanbootfromsdcard

echo "Unmounting..."
umount $TMPDIR
rm -r $TMPDIR

echo "Done."
