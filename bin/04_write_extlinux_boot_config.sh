#!/bin/bash
# This script writes the extlinux boot configuration to the cache partition of the SD card,
# where it is picked up by the U-Boot bootloader.
set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

# Check if a device was provided as an argument
if [[ -z "$1" ]]; then
  echo "Usage: $0 /dev/sdX [--rw]"
  exit 1
fi

DEVICE="$1"

if [[ ! -b "$DEVICE" ]]; then
  echo "Error: $DEVICE is not a valid block device."
  exit 1
fi

if [[ "$2" == "--rw" ]]; then
  DT_MOUNT_MODE="rw"
else
  DT_MOUNT_MODE="ro"
fi

CACHEMOUNTDIR="$(mktemp -d)"
echo "CACHEMOUNTDIR=$CACHEMOUNTDIR"

echo "Mounting ${DEVICE}3 partition..."
mount ${DEVICE}3 "$CACHEMOUNTDIR"

echo "Setting up folder structure..."
mkdir -p "$CACHEMOUNTDIR/boot"
mkdir -p "$CACHEMOUNTDIR/boot/extlinux"

getBootImageJSONValue() {
  jq -r "$1" ~/Android_boot_image_editor/build/unzip_boot/boot.json
}

CMDLINE=$(getBootImageJSONValue '.info.cmdline')
echo "CMDLINE=$CMDLINE"

echo "Writing extlinux configuration..."
cp patch/extlinux.conf.template "$CACHEMOUNTDIR/boot/extlinux/extlinux.conf"
cp patch/fstab-microsd.dtbo "$CACHEMOUNTDIR/boot/fstab-microsd.dtbo"
sed -i "s|\[CMDLINE\]|$CMDLINE|g" "$CACHEMOUNTDIR/boot/extlinux/extlinux.conf"
if [[ "$DT_MOUNT_MODE" == "rw" ]]; then
  FDTOVERLAYS="/boot/fstab-microsd.dtbo /boot/fstab-microsd-rw.dtbo"
  cp patch/fstab-microsd-rw.dtbo "$CACHEMOUNTDIR/boot/fstab-microsd-rw.dtbo"
else
  FDTOVERLAYS="/boot/fstab-microsd.dtbo"
fi
sed -i "s|\[FDTOVERLAYS\]|$FDTOVERLAYS|g" "$CACHEMOUNTDIR/boot/extlinux/extlinux.conf"

echo "Copying kernel and ramdisk..."
cp Android_boot_image_editor/build/unzip_boot/kernel "$CACHEMOUNTDIR/boot/kernel"
cp Android_boot_image_editor/build/unzip_boot/ramdisk.img.gz "$CACHEMOUNTDIR/boot/ramdisk.img.gz"

echo "Extracting and copying device tree blob..."
TEMPDTBDIR="$(mktemp -d)"
echo "TEMPDTBDIR=$TEMPDTBDIR"
python3 extract-dtb/extract_dtb/extract_dtb.py -o ${TEMPDTBDIR} Android_boot_image_editor/build/unzip_boot/kernel
DTBFILE=$(ls ${TEMPDTBDIR}/*.dtb | head -n 1)
echo "Using DTB file: $DTBFILE"
cp "$DTBFILE" "$CACHEMOUNTDIR/boot/dtb"

echo "Syncing and cleaning up..."
sync
umount "$CACHEMOUNTDIR"
rm -rf "$CACHEMOUNTDIR"
rm -rf "$TEMPDTBDIR"

echo "Done."