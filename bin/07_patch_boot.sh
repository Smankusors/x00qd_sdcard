#!/bin/bash
set -e

source work/config
source bin/lib/dtb_fstab.sh
source bin/lib/boot_image.sh
source bin/lib/vendor_fstab.sh

BOOT_IMAGE_DIR=Android_boot_image_editor/build/unzip_boot

echo "Extracting device trees..."
TMPDIR="$(mktemp -d)"
echo "TMPDIR=$TMPDIR"
cp "$BOOT_IMAGE_DIR/kernel" "$TMPDIR/kernel"
if [[ -s "$BOOT_IMAGE_DIR/dtb" ]]; then
  DTB_SOURCE="$BOOT_IMAGE_DIR/dtb"
  PATCH_KERNEL_DTB=0
  echo "Extracting device trees from boot image DTB..."
else
  DTB_SOURCE="$TMPDIR/kernel"
  PATCH_KERNEL_DTB=1
  echo "Extracting appended device trees from kernel..."
fi
python3 extract-dtb/extract_dtb/extract_dtb.py -o "$TMPDIR/out" "$DTB_SOURCE"

shopt -s nullglob
DTBFILES=("$TMPDIR"/out/*.dtb)
shopt -u nullglob
if [[ ${#DTBFILES[@]} -eq 0 ]]; then
  echo "Error: no device tree blobs found in $DTB_SOURCE." >&2
  exit 1
fi

if ! BOOT_DTB="$(select_dtb "$TMPDIR/out")" || [[ ! -f "$BOOT_DTB" ]]; then
  echo "Error: unable to select a device tree blob from $TMPDIR/out for this board." >&2
  exit 1
fi

echo "Patching selected device tree..."
if dtb_has_fstab_nodes "$BOOT_DTB" "$VENDOR_LAYOUT"; then
  fdtoverlay -i "$BOOT_DTB" -o "$BOOT_DTB" patch/fstab-microsd.dtbo
else
  echo "No compatible fstab entries for VENDOR_LAYOUT=$VENDOR_LAYOUT in $BOOT_DTB; using the ramdisk fstab."
fi

if [[ "$PATCH_KERNEL_DTB" -eq 1 ]]; then
  echo "Concatenating device trees..."
  cat "${DTBFILES[@]}" > "$TMPDIR/dtb"

  echo "Appending patched device trees..."
  cat "$TMPDIR/out/00_kernel" "$TMPDIR/dtb" > "$BOOT_IMAGE_DIR/kernel"
else
  echo "Updating boot image DTB..."
  cat "${DTBFILES[@]}" > "$BOOT_IMAGE_DIR/dtb"
  rm -f -- "$BOOT_IMAGE_DIR"/dtb*.dts
fi

repack_boot_image

rm -rf -- "$TMPDIR"
echo "Done."
