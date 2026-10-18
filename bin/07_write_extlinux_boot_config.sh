#!/bin/bash
# This script writes the extlinux boot configuration to the boot partition of the SD card,
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

source work/config

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

BOOTMOUNTDIR="$(mktemp -d)"
echo "BOOTMOUNTDIR=$BOOTMOUNTDIR"

echo "Mounting ${DEVICE}1 partition..."
mount ${DEVICE}1 "$BOOTMOUNTDIR"

echo "Setting up folder structure..."
mkdir -p "$BOOTMOUNTDIR"
mkdir -p "$BOOTMOUNTDIR/extlinux"

BOOT_JSON=~/Android_boot_image_editor/build/unzip_boot/boot.json
EXTLINUX_CONF="$BOOTMOUNTDIR/extlinux/extlinux.conf"
echo "Writing extlinux configuration..."
cp patch/extlinux.conf.template "$EXTLINUX_CONF"
cp patch/fstab-microsd.dtbo "$BOOTMOUNTDIR/fstab-microsd.dtbo"
if [[ "$DT_MOUNT_MODE" == "rw" ]]; then
  FDTOVERLAYS="/fstab-microsd.dtbo /fstab-microsd-rw.dtbo"
  cp patch/fstab-microsd-rw.dtbo "$BOOTMOUNTDIR/fstab-microsd-rw.dtbo"
else
  FDTOVERLAYS="/fstab-microsd.dtbo"
fi
python3 bin/render_extlinux_config.py "$BOOT_JSON" "$EXTLINUX_CONF" "$FDTOVERLAYS"

echo "Copying kernel and ramdisk..."
cp Android_boot_image_editor/build/unzip_boot/kernel "$BOOTMOUNTDIR/kernel"
cp Android_boot_image_editor/build/unzip_boot/ramdisk.img.gz "$BOOTMOUNTDIR/ramdisk.img.gz"

echo "Extracting and copying device tree blob..."
TEMPDTBDIR="$(mktemp -d)"
echo "TEMPDTBDIR=$TEMPDTBDIR"
python3 extract-dtb/extract_dtb/extract_dtb.py -o ${TEMPDTBDIR} Android_boot_image_editor/build/unzip_boot/kernel
DTBFILE=$(select_dtb $TEMPDTBDIR)
echo "Using DTB file: $DTBFILE"
cp "$DTBFILE" "$BOOTMOUNTDIR/dtb"

echo "Syncing and cleaning up..."
sync
umount "$BOOTMOUNTDIR"
rm -rf "$BOOTMOUNTDIR"
rm -rf "$TEMPDTBDIR"

echo "Done."