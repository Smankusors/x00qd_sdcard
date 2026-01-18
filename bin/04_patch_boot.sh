#!/bin/bash
set -e

if [[ "$1" == "--rw" ]]; then
  DT_MOUNT_MODE="rw"
else
  DT_MOUNT_MODE="ro"
fi

source work/config

echo "Extracting device trees..."
TMPDIR="$(mktemp -d)"
echo "TMPDIR=$TMPDIR"
cp Android_boot_image_editor/build/unzip_boot/kernel $TMPDIR/kernel
python3 extract-dtb/extract_dtb/extract_dtb.py -o $TMPDIR/out $TMPDIR/kernel

echo "Patching device trees..."
for file in $TMPDIR/out/*.dtb; do
  if [[ "$DT_MOUNT_MODE" == "rw" ]]; then
    fdtoverlay -i $file -o $file patch/fstab-microsd.dtbo patch/fstab-microsd-rw.dtbo
  else
    fdtoverlay -i $file -o $file patch/fstab-microsd.dtbo
  fi
done

echo "Concatenating device trees..."
cat ${TMPDIR}/out/*.dtb > ${TMPDIR}/dtb

echo "Appending patched device trees..."
cat ${TMPDIR}/out/00_kernel ${TMPDIR}/dtb > Android_boot_image_editor/build/unzip_boot/kernel

echo "Repacking boot.img..."
getBootImageJSONValue() {
  jq -r "$1" ~/Android_boot_image_editor/build/unzip_boot/boot.json
}
BOOT_RAMDISK=$(getBootImageJSONValue '.ramdisk.file')
BOOT_BASE=$(getBootImageJSONValue '.info.loadBase')
BOOT_SECOND_OFFSET=$(getBootImageJSONValue '.secondBootloader.loadOffset // 0')
BOOT_CMDLINE=$(getBootImageJSONValue '.info.cmdline')
BOOT_KERNEL_OFFSET=$(getBootImageJSONValue '.kernel.loadOffset')
BOOT_RAMDISK_OFFSET=$(getBootImageJSONValue '.ramdisk.loadOffset')
BOOT_TAGS_OFFSET=$(getBootImageJSONValue '.info.tagsOffset')
BOOT_PAGESIZE=$(getBootImageJSONValue '.info.pageSize')
BOOT_DTB=$(select_dtb "$TMPDIR/out")
BOOT_OS_VERSION=$(getBootImageJSONValue '.info.osVersion')
BOOT_OS_PATCH_LEVEL=$(getBootImageJSONValue '.info.osPatchLevel')

set -x
python3 Android_boot_image_editor/aosp/system/tools/mkbootimg/mkbootimg.py \
  --header_version 2 \
  --kernel Android_boot_image_editor/build/unzip_boot/kernel \
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
