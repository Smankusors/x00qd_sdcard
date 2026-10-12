mount_vendor_image() {
  case "${VENDOR_LAYOUT:-}" in
    separate)
      VENDOR_IMAGE="work/vendor.img"
      ;;
    system)
      VENDOR_IMAGE="work/system.img"
      ;;
  esac

  VENDOR_MOUNT_POINT="$(mktemp -d)"
  echo "Mounting $VENDOR_IMAGE to $VENDOR_MOUNT_POINT..."
  mount "$VENDOR_IMAGE" "$VENDOR_MOUNT_POINT"
  VENDOR_IMAGE_MOUNTED=1
  VENDOR_MOUNT_ROOT="$(realpath -e -- "$VENDOR_MOUNT_POINT")"
}

cleanup_vendor_image() {
  if [[ "${VENDOR_IMAGE_MOUNTED:-0}" -eq 1 ]]; then
    echo "Unmounting..."
    umount "$VENDOR_MOUNT_POINT"
    VENDOR_IMAGE_MOUNTED=0
  fi
  if [[ -n "${VENDOR_MOUNT_POINT:-}" ]]; then
    rmdir "$VENDOR_MOUNT_POINT" 2>/dev/null || true
  fi
}

find_vendor_file() {
  local relative_path="$1"
  local candidate
  local -a candidates

  if [[ "$VENDOR_LAYOUT" == separate ]]; then
    candidates=("$VENDOR_MOUNT_ROOT")
  else
    candidates=(
      "$VENDOR_MOUNT_ROOT/vendor"
      "$VENDOR_MOUNT_ROOT/system/vendor"
      "$VENDOR_MOUNT_ROOT"
    )
  fi

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate/$relative_path" ]]; then
      printf '%s\n' "$candidate/$relative_path"
      return 0
    fi
  done

  return 1
}
