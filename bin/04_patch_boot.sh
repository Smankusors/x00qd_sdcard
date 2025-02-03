#!/bin/bash
set -e

echo "Unpacking boot.img..."
cp work/boot.img Android_boot_image_editor-master/boot.img
./Android_boot_image_editor-master/gradlew -p Android_boot_image_editor-master unpack

echo "Extracting device trees..."
TMPDIR="$(mktemp -d)"
echo "TMPDIR=$TMPDIR"
cp Android_boot_image_editor-master/build/unzip_boot/kernel ${TMPDIR}/kernel
python3 extract-dtb-master/extract_dtb/extract_dtb.py -o ${TMPDIR}/out ${TMPDIR}/kernel

KERNEL_VERSION=$(cat Android_boot_image_editor-master/build/unzip_boot/kernel_version.txt)
echo "Kernel version: $KERNEL_VERSION"
if [[ $KERNEL_VERSION == "4.4"* ]]; then
  for file in ${TMPDIR}/out/*.dtb; do
    if [[ $(strings $file | grep -c "ARA-ER") -eq 0 ]]; then
      echo "Removing $file..."
      rm $file
    fi
  done
  echo "Using dts_4.4.patch"
  cp patch/dts_4.4.patch ${TMPDIR}/dts.patch
elif [[ $KERNEL_VERSION == "4.19"* ]]; then
  echo "Using dts_4.19.patch"
  cp patch/dts_4.19.patch ${TMPDIR}/dts.patch
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
cat ${TMPDIR}/kernel ${TMPDIR}/dtb > Android_boot_image_editor-master/build/unzip_boot/kernel

echo "Repacking boot.img..."
getJSONValue() {
  python3 - <<PYTHON
import json
import sys
try:
  with open('Android_boot_image_editor-master/build/unzip_boot/boot.json') as f:
    print(json.load(f)$1)
except Exception as e:
  print(f"Error: Could not find key $1 in boot.json", file=sys.stderr)
  raise e
PYTHON
}
BOOT_RAMDISK=$(getJSONValue "['ramdisk']['file']")
BOOT_BASE=$(getJSONValue "['info']['loadBase']")
BOOT_SECOND_OFFSET=$(getJSONValue "['secondBootloader']['loadOffset']" || echo 0)
BOOT_CMDLINE=$(getJSONValue "['info']['cmdline']")
BOOT_KERNEL_OFFSET=$(getJSONValue "['kernel']['loadOffset']")
BOOT_RAMDISK_OFFSET=$(getJSONValue "['ramdisk']['loadOffset']")
BOOT_TAGS_OFFSET=$(getJSONValue "['info']['tagsOffset']")
BOOT_PAGESIZE=$(getJSONValue "['info']['pageSize']")
BOOT_DTB="${TMPDIR}/dtb"
BOOT_OS_VERSION=$(getJSONValue "['info']['osVersion']")
BOOT_OS_PATCH_LEVEL=$(getJSONValue "['info']['osPatchLevel']")
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

mkbootimg \
  --header_version 2 \
  --kernel Android_boot_image_editor-master/build/unzip_boot/kernel \
  --ramdisk "Android_boot_image_editor-master/${BOOT_RAMDISK}" \
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
