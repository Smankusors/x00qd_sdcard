#!/bin/bash
set -e

source work/config
source bin/lib/dtb_fstab.sh
source bin/lib/vendor_fstab.sh
source bin/lib/boot_image.sh
source bin/lib/boot_image_patch.sh

BOOT_IMAGE_DIR="Android_boot_image_editor/build/unzip_boot"

prepare_boot_image_tree "$BOOT_IMAGE_DIR" "$VENDOR_LAYOUT"
repack_boot_image

echo "Done."
