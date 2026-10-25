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
source bin/lib/dtb_fstab.sh
source bin/lib/vendor_fstab.sh
RAMDISK_ROOT="Android_boot_image_editor/build/unzip_boot/root"
POLICY_TEMP=""
BOOT_IMAGE_REPACK_REQUIRED=0
cleanup() {
  if [[ -n "$POLICY_TEMP" ]]; then
    rm -f -- "$POLICY_TEMP"
  fi
  cleanup_vendor_image
}
trap cleanup EXIT
mount_vendor_image

INIT_QCOM_RC_PATH="etc/init/hw/init.qcom.rc"
VENDOR_SEPOLICY_CIL="$(find_vendor_path etc/selinux/vendor_sepolicy.cil || true)"
if [[ -n "$VENDOR_SEPOLICY_CIL" && ! -f "$VENDOR_SEPOLICY_CIL" ]]; then
  echo "Error: expected a vendor policy file, but found a directory: $VENDOR_SEPOLICY_CIL." >&2
  exit 1
fi
INIT_RC_IN_VENDOR_INIT=0
INIT_RC_IN_RAMDISK=0
VENDOR_INIT_DIR=""
VENDOR_INIT_METADATA_TEMPLATE=""

INIT_RC_FILE="$(find_vendor_path "$INIT_QCOM_RC_PATH" || true)"
if [[ -n "$INIT_RC_FILE" && ! -f "$INIT_RC_FILE" ]]; then
  echo "Error: expected a vendor init rc file, but found a directory: $INIT_RC_FILE." >&2
  exit 1
fi

if [[ -z "$INIT_RC_FILE" ]]; then
  if VENDOR_INIT_DIR="$(find_vendor_path etc/init)"; then
    if [[ ! -d "$VENDOR_INIT_DIR" ]]; then
      echo "Error: expected a vendor init directory, but found a file: $VENDOR_INIT_DIR." >&2
      exit 1
    fi
    for candidate in "$VENDOR_INIT_DIR"/*.rc; do
      if [[ -f "$candidate" && ! -L "$candidate" ]]; then
        VENDOR_INIT_METADATA_TEMPLATE="$candidate"
        break
      fi
    done
  else
    FIND_VENDOR_INIT_STATUS=$?
    if [[ "$FIND_VENDOR_INIT_STATUS" -ne 1 ]]; then
      exit 1
    fi
  fi

  if [[ -n "$VENDOR_INIT_METADATA_TEMPLATE" ]]; then
    # Android imports rc files from vendor/etc/init, so this avoids modifying an
    # unrelated device-specific rc file.
    INIT_RC_FILE="$VENDOR_INIT_DIR/zz_debug_logs.rc"
    INIT_RC_IN_VENDOR_INIT=1
  fi
fi

if [[ -z "$INIT_RC_FILE" ]]; then
  for candidate in \
    "$RAMDISK_ROOT/init.rc" \
    "$RAMDISK_ROOT/etc/init/hw/init.rc" \
    "$RAMDISK_ROOT/init.qcom.rc" \
    "$RAMDISK_ROOT/etc/init/hw/init.qcom.rc" \
    "$RAMDISK_ROOT/vendor/etc/init/hw/init.qcom.rc"; do
    if [[ -f "$candidate" && ! -L "$candidate" ]]; then
      INIT_RC_FILE="$candidate"
      INIT_RC_IN_RAMDISK=1
      break
    fi
  done
fi

if [[ -z "$INIT_RC_FILE" ]]; then
  echo "Error: no vendor init directory, init.qcom.rc, or compatible init.rc found in $VENDOR_IMAGE or the boot ramdisk." >&2
  exit 1
fi

patch_init_config() {
  if [[ "$INIT_RC_IN_VENDOR_INIT" -eq 1 ]]; then
    if [[ -e "$INIT_RC_FILE" || -L "$INIT_RC_FILE" ]]; then
      local existing_file
      if ! existing_file="$(find_vendor_path etc/init/zz_debug_logs.rc)"; then
        echo "Error: refusing to append to unsafe or unreadable $INIT_RC_FILE." >&2
        return 1
      fi
      if [[ ! -f "$existing_file" ]]; then
        echo "Error: expected a vendor init rc file, but found a directory: $existing_file." >&2
        return 1
      fi
      if [[ "$existing_file" != "$INIT_RC_FILE" ]]; then
        echo "Error: $INIT_RC_FILE resolves outside the vendor init directory." >&2
        return 1
      fi
    else
      cp --attributes-only --preserve=all -- "$VENDOR_INIT_METADATA_TEMPLATE" "$INIT_RC_FILE"
    fi
  fi

  cat -- patch/log_from_init.rc >> "$INIT_RC_FILE"
}

if [[ -n "$VENDOR_SEPOLICY_CIL" ]]; then
  VENDOR_ROOT="${VENDOR_SEPOLICY_CIL%/etc/selinux/vendor_sepolicy.cil}"
  echo "Patching init config: $INIT_RC_FILE"
  patch_init_config
  echo "Patching split vendor sepolicy..."
  cat -- patch/log_from_init.cil >> "$VENDOR_SEPOLICY_CIL"
  rm -f -- "$VENDOR_ROOT/etc/selinux/precompiled_sepolicy"
  if [[ "$INIT_RC_IN_RAMDISK" -eq 1 ]]; then
    BOOT_IMAGE_REPACK_REQUIRED=1
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

  echo "Patching init config: $INIT_RC_FILE"
  patch_init_config
  mv -- "$POLICY_TEMP" "$MONOLITHIC_POLICY"
  POLICY_TEMP=""
  BOOT_IMAGE_REPACK_REQUIRED=1
fi

if set_boot_image_mount_rw "Android_boot_image_editor/build/unzip_boot" "$VENDOR_LAYOUT"; then
  BOOT_IMAGE_REPACK_REQUIRED=1
else
  case $? in
    1) ;;
    *)
      exit 1
      ;;
  esac
fi

RAMDISK_FSTAB_CHANGED=0
mapfile -d '' RAMDISK_FSTAB_FILES < <(find_ramdisk_fstab_files "$RAMDISK_ROOT")
for fstab in "${RAMDISK_FSTAB_FILES[@]}"; do
  set_fstab_mount_rw "$fstab" "$VENDOR_LAYOUT"
done
if [[ "$RAMDISK_FSTAB_CHANGED" -eq 1 ]]; then
  BOOT_IMAGE_REPACK_REQUIRED=1
fi

if [[ "$BOOT_IMAGE_REPACK_REQUIRED" -eq 1 ]]; then
  repack_boot_image
fi

echo "Done."
