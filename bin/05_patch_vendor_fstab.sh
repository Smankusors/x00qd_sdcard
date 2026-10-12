#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

source work/config
source bin/lib/vendor_image.sh

if (($#)); then
  echo "Usage: $0" >&2
  exit 1
fi

trap cleanup_vendor_image EXIT
mount_vendor_image

echo "Patching fstab.qcom..."
FSTABQCOMFILE="$(find_vendor_file etc/fstab.qcom || true)"
if [[ -z "$FSTABQCOMFILE" ]]; then
  echo "Error: fstab.qcom not found in $VENDOR_IMAGE."
  exit 1
fi
cp -- "$FSTABQCOMFILE" "$FSTABQCOMFILE.bak"
chcon --reference="$FSTABQCOMFILE" "$FSTABQCOMFILE.bak"
sed -i "/$MICROSD_ADDR/d" "$FSTABQCOMFILE"
sed -i "s/\/dev\/block\/bootdevice\/by-name\/userdata/\/dev\/block\/platform\/soc\/$MICROSD_ADDR\/by-name\/microsd_userdata/g" "$FSTABQCOMFILE"
sed -i "s/\/dev\/block\/bootdevice\/by-name\/cache/\/dev\/block\/platform\/soc\/$MICROSD_ADDR\/by-name\/microsd_cache/g" "$FSTABQCOMFILE"
chcon --reference="$FSTABQCOMFILE.bak" "$FSTABQCOMFILE"
rm "$FSTABQCOMFILE.bak"

echo "Done."
