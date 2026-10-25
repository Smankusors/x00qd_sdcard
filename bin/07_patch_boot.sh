#!/bin/bash
set -e

source work/config
source bin/lib/dtb_fstab.sh
source bin/lib/vendor_fstab.sh

BOOT_IMAGE_DIR=Android_boot_image_editor/build/unzip_boot
BOOT_JSON="$BOOT_IMAGE_DIR/boot.json"

echo "Extracting device trees..."
TMPDIR="$(mktemp -d)"
echo "TMPDIR=$TMPDIR"
cp "$BOOT_IMAGE_DIR/kernel" "$TMPDIR/kernel"
python3 extract-dtb/extract_dtb/extract_dtb.py -o "$TMPDIR/out" "$TMPDIR/kernel"

shopt -s nullglob
DTBFILES=("$TMPDIR"/out/*.dtb)
shopt -u nullglob
if [[ ${#DTBFILES[@]} -eq 0 ]]; then
  echo "Error: no appended device tree blobs found in the boot kernel." >&2
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

echo "Concatenating device trees..."
cat "${DTBFILES[@]}" > "$TMPDIR/dtb"

echo "Appending patched device trees..."
cat "$TMPDIR/out/00_kernel" "$TMPDIR/dtb" > "$BOOT_IMAGE_DIR/kernel"

echo "Repacking boot.img..."
getBootImageJSONValue() {
  jq -r "$1" "$BOOT_JSON"
}
BOOT_RAMDISK=$(getBootImageJSONValue '.ramdisk.file')
BOOT_BASE=$(getBootImageJSONValue '.info.loadBase')
BOOT_SECOND_OFFSET=$(getBootImageJSONValue '.secondBootloader.loadOffset // 0')
BOOT_CMDLINE=$(getBootImageJSONValue '.info.cmdline')
BOOT_KERNEL_OFFSET=$(getBootImageJSONValue '.kernel.loadOffset')
BOOT_RAMDISK_OFFSET=$(getBootImageJSONValue '.ramdisk.loadOffset')
BOOT_TAGS_OFFSET=$(getBootImageJSONValue '.info.tagsOffset')
BOOT_PAGESIZE=$(getBootImageJSONValue '.info.pageSize')
BOOT_OS_VERSION=$(getBootImageJSONValue '.info.osVersion')
BOOT_OS_PATCH_LEVEL=$(getBootImageJSONValue '.info.osPatchLevel')

set -x
python3 Android_boot_image_editor/aosp/system/tools/mkbootimg/mkbootimg.py \
  --header_version 2 \
  --kernel "$BOOT_IMAGE_DIR/kernel" \
  --ramdisk "${BOOT_RAMDISK}" \
  --base "${BOOT_BASE}" \
  --second_offset "${BOOT_SECOND_OFFSET}" \
  --cmdline "${BOOT_CMDLINE}" \
  --kernel_offset "${BOOT_KERNEL_OFFSET}" \
  --ramdisk_offset "${BOOT_RAMDISK_OFFSET}" \
  --tags_offset "${BOOT_TAGS_OFFSET}" \
  --pagesize "${BOOT_PAGESIZE}" \
  --dtb "${BOOT_DTB}" \
  --os_version "${BOOT_OS_VERSION}" \
  --os_patch_level "${BOOT_OS_PATCH_LEVEL}" \
  -o work/boot.img
set +x

rm -rf ${TMPDIR}
echo "Done."
