#!/bin/bash
set -e

source work/config
source bin/lib/dtb_fstab.sh
source bin/lib/vendor_fstab.sh
source bin/lib/boot_verity.sh
source bin/lib/boot_image.sh
source bin/lib/boot_image_patch.sh
source bin/lib/legacy_verity.sh

BOOT_IMAGE_DIR="Android_boot_image_editor/build/unzip_boot"

prepare_legacy_dm_verity_for_boot "$BOOT_IMAGE_DIR"
prepare_boot_image_tree "$BOOT_IMAGE_DIR" "$VENDOR_LAYOUT"
repack_boot_image

echo "Done."
