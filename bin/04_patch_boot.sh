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

echo "Patching device trees..."
for file in ${TMPDIR}/out/*.dtb; do
  dtc -I dtb -O dts -o "${file%.dtb}.dts" "$file"
  patch "${file%.dtb}.dts" < patch/dts.patch
  dtc -I dts -O dtb -o "$file" "${file%.dtb}.dts"
done

echo "Appending patched device trees..."
cat ${TMPDIR}/out/00_kernel ${TMPDIR}/out/*.dtb > Android_boot_image_editor-master/build/unzip_boot/kernel
rm -rf ${TMPDIR}

echo "Repacking boot.img..."
./Android_boot_image_editor-master/gradlew -p Android_boot_image_editor-master pack
mv Android_boot_image_editor-master/boot.img.signed work/boot.img

echo "Done."
