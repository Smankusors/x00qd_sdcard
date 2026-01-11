#!/bin/bash
set -e

if [[ "$1" == "--rw" ]]; then
  DT_MOUNT_MODE="rw"
else
  DT_MOUNT_MODE="ro"
fi

echo "Extracting device trees..."
TMPDIR="$(mktemp -d)"
echo "TMPDIR=$TMPDIR"
cp Android_boot_image_editor/build/unzip_boot/kernel ${TMPDIR}/kernel
python3 extract-dtb/extract_dtb/extract_dtb.py -o ${TMPDIR}/out ${TMPDIR}/kernel

KERNEL_VERSION=$(cat Android_boot_image_editor/build/unzip_boot/kernel_version.txt)
echo "Kernel version: $KERNEL_VERSION"
if [[ $KERNEL_VERSION == "4.4"* ]]; then
  for file in ${TMPDIR}/out/*.dtb; do
    if [[ $(strings $file | grep -c "ARA-ER") -eq 0 ]]; then
      echo "Removing $file..."
      rm $file
    fi
  done
  if [[ "$DT_MOUNT_MODE" == "rw" ]]; then
    echo "Using dts 4.4 rw patch"
    cp patch/dts_4.4_rw.patch ${TMPDIR}/dts.patch
  else
    echo "Using dts 4.4 ro patch"
    cp patch/dts_4.4.patch ${TMPDIR}/dts.patch
  fi
elif [[ $KERNEL_VERSION == "4.19"* ]]; then
  if [[ "$DT_MOUNT_MODE" == "rw" ]]; then
    echo "Using dts 4.19 rw patch"
    cp patch/dts_4.19_rw.patch ${TMPDIR}/dts.patch
  else
    echo "Using dts 4.19 ro patch"
    cp patch/dts_4.19.patch ${TMPDIR}/dts.patch
  fi
else
  echo "Error: Unsupported kernel version $KERNEL_VERSION"
  exit 1
fi

echo "Patching device trees..."
for file in ${TMPDIR}/out/*.dtb; do
  dtc -I dtb -O dts -o "${file%.dtb}.dts" "$file"
  patch "${file%.dtb}.dts" < ${TMPDIR}/dts.patch
  dtc -I dts -O dtb -o "$file" "${file%.dtb}.dts"
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
BOOT_SECOND_OFFSET=$(getBootImageJSONValue '.secondBootloader.loadOffset' || echo 0)
BOOT_CMDLINE=$(getBootImageJSONValue '.info.cmdline')
BOOT_KERNEL_OFFSET=$(getBootImageJSONValue '.kernel.loadOffset')
BOOT_RAMDISK_OFFSET=$(getBootImageJSONValue '.ramdisk.loadOffset')
BOOT_TAGS_OFFSET=$(getBootImageJSONValue '.info.tagsOffset')
BOOT_PAGESIZE=$(getBootImageJSONValue '.info.pageSize')
BOOT_DTB="${TMPDIR}/dtb"
BOOT_OS_VERSION=$(getBootImageJSONValue '.info.osVersion')
BOOT_OS_PATCH_LEVEL=$(getBootImageJSONValue '.info.osPatchLevel')
echo "BOOT_RAMDISK=$BOOT_RAMDISK"
echo "BOOT_BASE=$BOOT_BASE"
echo "BOOT_SECOND_OFFSET=$BOOT_SECOND_OFFSET"
echo "BOOT_CMDLINE=$BOOT_CMDLINE"
echo "BOOT_KERNEL_OFFSET=$BOOT_KERNEL_OFFSET"
echo "BOOT_RAMDISK_OFFSET=$BOOT_RAMDISK_OFFSET"
echo "BOOT_TAGS_OFFSET=$BOOT_TAGS_OFFSET"
echo "BOOT_PAGESIZE=$BOOT_PAGESIZE"
echo "BOOT_DTB=$BOOT_DTB"
echo "BOOT_OS_VERSION=$BOOT_OS_VERSION"
echo "BOOT_OS_PATCH_LEVEL=$BOOT_OS_PATCH_LEVEL"

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

rm -rf ${TMPDIR}
echo "Done."
