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
source bin/lib/boot_image.sh
RAMDISK_ROOT="Android_boot_image_editor/build/unzip_boot/root"
POLICY_TEMP=""
cleanup() {
  if [[ -n "$POLICY_TEMP" ]]; then
    rm -f -- "$POLICY_TEMP"
  fi
  cleanup_vendor_image
}
trap cleanup EXIT
mount_vendor_image

INIT_QCOM_RC_PATH="etc/init/hw/init.qcom.rc"
VENDOR_SEPOLICY_CIL="$(find_vendor_file etc/selinux/vendor_sepolicy.cil || true)"
INIT_QCOM_RC_FILE="$(find_vendor_file "$INIT_QCOM_RC_PATH" || true)"
INIT_QCOM_RC_IN_RAMDISK=0
if [[ -z "$INIT_QCOM_RC_FILE" ]]; then
  for candidate in \
    "$RAMDISK_ROOT/init.qcom.rc" \
    "$RAMDISK_ROOT/etc/init/hw/init.qcom.rc" \
    "$RAMDISK_ROOT/vendor/etc/init/hw/init.qcom.rc" \
    "$RAMDISK_ROOT/init.rc" \
    "$RAMDISK_ROOT/etc/init/hw/init.rc"; do
    if [[ -f "$candidate" && ! -L "$candidate" ]]; then
      INIT_QCOM_RC_FILE="$candidate"
      INIT_QCOM_RC_IN_RAMDISK=1
      break
    fi
  done
fi
if [[ -z "$INIT_QCOM_RC_FILE" ]]; then
  echo "Error: init.qcom.rc or init.rc not found in $VENDOR_IMAGE or the boot ramdisk." >&2
  exit 1
fi

if [[ -n "$VENDOR_SEPOLICY_CIL" ]]; then
  VENDOR_ROOT="${VENDOR_SEPOLICY_CIL%/etc/selinux/vendor_sepolicy.cil}"
  echo "Patching init.qcom.rc..."
  cat -- patch/log_from_init.rc >> "$INIT_QCOM_RC_FILE"
  echo "Patching split vendor sepolicy..."
  cat -- patch/log_from_init.cil >> "$VENDOR_SEPOLICY_CIL"
  rm -f -- "$VENDOR_ROOT/etc/selinux/precompiled_sepolicy"
  if [[ "$INIT_QCOM_RC_IN_RAMDISK" -eq 1 ]]; then
    repack_boot_image
  fi
else
  MONOLITHIC_POLICY="$RAMDISK_ROOT/sepolicy"
  if [[ ! -f "$MONOLITHIC_POLICY" || -L "$MONOLITHIC_POLICY" ]]; then
    echo "Error: neither vendor_sepolicy.cil nor a boot ramdisk /sepolicy was found." >&2
    exit 1
  fi
  if ! command -v sepolicy-inject >/dev/null 2>&1; then
    echo "Error: sepolicy-inject is required to patch a monolithic policy. Rebuild the Docker image." >&2
    exit 1
  fi

  POLICY_TEMP="$(mktemp "$MONOLITHIC_POLICY.x00qd.XXXXXX")"
  cp --preserve=all -- "$MONOLITHIC_POLICY" "$POLICY_TEMP"
  echo "Patching monolithic boot policy..."
  while read -r source_type target_type class permissions; do
    [[ -z "$source_type" || "$source_type" == \#* ]] && continue
    if [[ "$target_type" == self ]]; then
      target_type="$source_type"
    fi
    sepolicy-inject \
      -s "$source_type" \
      -t "$target_type" \
      -c "$class" \
      -p "$permissions" \
      -P "$POLICY_TEMP"
  done < patch/log_from_init.policy

  echo "Patching init.qcom.rc..."
  cat -- patch/log_from_init.rc >> "$INIT_QCOM_RC_FILE"
  mv -- "$POLICY_TEMP" "$MONOLITHIC_POLICY"
  POLICY_TEMP=""
  repack_boot_image
fi

echo "Done."
