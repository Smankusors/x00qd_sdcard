#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

source work/config
source bin/lib/vendor_image.sh
source bin/lib/boot_image.sh
source bin/lib/vendor_fstab.sh

trap cleanup_vendor_image EXIT
mount_vendor_image

echo "Patching fstab.qcom..."
FSTABQCOMFILE="$(find_vendor_path etc/fstab.qcom || true)"
if [[ -z "$FSTABQCOMFILE" ]]; then
  echo "Error: fstab.qcom not found in $VENDOR_IMAGE."
  exit 1
fi
if [[ ! -f "$FSTABQCOMFILE" ]]; then
  echo "Error: expected fstab.qcom to be a file, but found a directory: $FSTABQCOMFILE." >&2
  exit 1
fi
cp -- "$FSTABQCOMFILE" "$FSTABQCOMFILE.bak"
chcon --reference="$FSTABQCOMFILE" "$FSTABQCOMFILE.bak"
replace_fstab_device_paths "$FSTABQCOMFILE"
chcon --reference="$FSTABQCOMFILE.bak" "$FSTABQCOMFILE"
rm "$FSTABQCOMFILE.bak"

RAMDISK_ROOT="Android_boot_image_editor/build/unzip_boot/root"
mapfile -d '' RAMDISK_FSTAB_FILES < <(find_ramdisk_fstab_files "$RAMDISK_ROOT")
for fstab in "${RAMDISK_FSTAB_FILES[@]}"; do
  replace_fstab_device_paths "$fstab"
done
if ((${#RAMDISK_FSTAB_FILES[@]})); then
  repack_boot_image
fi

echo "Done."
