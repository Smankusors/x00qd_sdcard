#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

if (($#)); then
  echo "Usage: $0" >&2
  exit 1
fi

source work/config
source bin/lib/vendor_image.sh
trap cleanup_vendor_image EXIT
mount_vendor_image

INIT_QCOM_RC_PATH="etc/init/hw/init.qcom.rc"
VENDOR_SEPOLICY_CIL="$(find_vendor_file etc/selinux/vendor_sepolicy.cil || true)"
if [[ -z "$VENDOR_SEPOLICY_CIL" ]]; then
  echo "Error: vendor_sepolicy.cil not found in $VENDOR_IMAGE." >&2
  exit 1
fi
VENDOR_ROOT="${VENDOR_SEPOLICY_CIL%/etc/selinux/vendor_sepolicy.cil}"

INIT_QCOM_RC_FILE="$(find_vendor_file "$INIT_QCOM_RC_PATH" || true)"
if [[ -z "$INIT_QCOM_RC_FILE" ]]; then
  echo "Error: init.qcom.rc not found in $VENDOR_IMAGE." >&2
  exit 1
fi

echo "Patching init.qcom.rc..."
cat -- patch/log_from_init.rc >> "$INIT_QCOM_RC_FILE"
echo "Patching vendor sepolicy..."
cat -- patch/log_from_init.cil >> "$VENDOR_SEPOLICY_CIL"
rm -f "$VENDOR_ROOT/etc/selinux/precompiled_sepolicy"

echo "Done."
