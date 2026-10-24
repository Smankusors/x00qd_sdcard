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
source bin/lib/dtb_fstab.sh

DEVICE="$1"

if [[ ! -b "$DEVICE" ]]; then
  echo "Error: $DEVICE is not a valid block device."
  exit 1
fi

if [[ "$2" == "--rw" ]]; then
  SET_MOUNT_RW=1
else
  SET_MOUNT_RW=0
fi

BOOTMOUNTDIR="$(mktemp -d)"
echo "BOOTMOUNTDIR=$BOOTMOUNTDIR"

echo "Mounting ${DEVICE}1 partition..."
mount ${DEVICE}1 "$BOOTMOUNTDIR"

echo "Setting up folder structure..."
mkdir -p "$BOOTMOUNTDIR"
mkdir -p "$BOOTMOUNTDIR/extlinux"

BOOT_IMAGE_DIR=Android_boot_image_editor/build/unzip_boot
BOOT_JSON="$BOOT_IMAGE_DIR/boot.json"
EXTLINUX_CONF="$BOOTMOUNTDIR/extlinux/extlinux.conf"
echo "Writing extlinux configuration..."
cp patch/extlinux.conf.template "$EXTLINUX_CONF"
python3 bin/render_extlinux_config.py "$BOOT_JSON" "$EXTLINUX_CONF"

echo "Copying kernel and ramdisk..."
cp "$BOOT_IMAGE_DIR/kernel" "$BOOTMOUNTDIR/kernel"
cp "$BOOT_IMAGE_DIR/ramdisk.img.gz" "$BOOTMOUNTDIR/ramdisk.img.gz"

echo "Extracting and copying device tree blob..."
TEMPDTBDIR="$(mktemp -d)"
echo "TEMPDTBDIR=$TEMPDTBDIR"
if [[ -s "$BOOT_IMAGE_DIR/dtb" ]]; then
  DTB_SOURCE="$BOOT_IMAGE_DIR/dtb"
  echo "Extracting device trees from boot image DTB..."
else
  DTB_SOURCE="$BOOT_IMAGE_DIR/kernel"
  echo "Extracting appended device trees from kernel..."
fi
python3 extract-dtb/extract_dtb/extract_dtb.py -o "$TEMPDTBDIR" "$DTB_SOURCE"

shopt -s nullglob
DTBFILES=("$TEMPDTBDIR"/*.dtb)
shopt -u nullglob
if [[ ${#DTBFILES[@]} -eq 0 ]]; then
  echo "Error: no device tree blobs found in $DTB_SOURCE." >&2
  exit 1
fi

DTBFILE="$(select_dtb "$TEMPDTBDIR")"
if [[ -z "$DTBFILE" || ! -f "$DTBFILE" ]]; then
  echo "Error: unable to select a device tree blob from $TEMPDTBDIR for this board." >&2
  exit 1
fi
echo "Using DTB file: $DTBFILE"
if [[ "$SET_MOUNT_RW" -eq 1 ]]; then
  if [[ "$VENDOR_LAYOUT" == "separate" ]]; then
    set_dtb_mount_rw "$DTBFILE" system vendor
  else
    set_dtb_mount_rw "$DTBFILE" system
  fi
fi
fdtoverlay -i "$DTBFILE" -o "$BOOTMOUNTDIR/dtb" patch/fstab-microsd.dtbo

echo "Syncing and cleaning up..."
sync
umount "$BOOTMOUNTDIR"
rm -rf "$BOOTMOUNTDIR"
rm -rf "$TEMPDTBDIR"

echo "Done."
