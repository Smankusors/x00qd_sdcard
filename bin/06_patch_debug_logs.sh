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
INIT_QCOM_RC_FILE="$(find_vendor_file "$INIT_QCOM_RC_PATH" || true)"
if [[ -z "$INIT_QCOM_RC_FILE" ]]; then
  echo "Error: init.qcom.rc not found in $VENDOR_IMAGE." >&2
  exit 1
fi
VENDOR_ROOT="${INIT_QCOM_RC_FILE%/$INIT_QCOM_RC_PATH}"

resolve_vendor_debug_destination() {
  local destination="$VENDOR_ROOT/$1"
  local canonical

  canonical="$(realpath -e -- "$destination" 2>/dev/null)" || {
    echo "Missing vendor debug destination: $destination" >&2
    return 1
  }
  if [[ "$canonical" != "$destination" || ! -f "$canonical" ]]; then
    echo "Refusing unsafe vendor debug destination: $destination" >&2
    return 1
  fi
  printf '%s\n' "$canonical"
}

if [[ ! -e "$VENDOR_ROOT/etc/selinux/vendor_sepolicy.cil" ]]; then
  echo "Error: vendor_sepolicy.cil is missing. This step currently requires that file; other policy layouts, including ramdisk /sepolicy, are not handled yet." >&2
  exit 1
fi

INIT_QCOM_RC_FILE="$(resolve_vendor_debug_destination "$INIT_QCOM_RC_PATH")"
VENDOR_SEPOLICY_FILE="$(resolve_vendor_debug_destination etc/selinux/vendor_sepolicy.cil)"

echo "Patching init.qcom.rc..."
cat -- patch/log_from_init.rc >> "$INIT_QCOM_RC_FILE"
echo "Patching vendor sepolicy..."
cat -- patch/log_from_init.cil >> "$VENDOR_SEPOLICY_FILE"
rm -f "$VENDOR_ROOT/etc/selinux/precompiled_sepolicy"

echo "Done."
