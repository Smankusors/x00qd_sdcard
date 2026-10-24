source bin/lib/image_file.sh

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

# System images vary in where vendor files live. Search vendor-scoped roots
# first so a same-named file at the image root cannot shadow vendor config.
# Resolve matches before callers edit a file or create one in a directory.
vendor_image_roots() {
  if [[ "$VENDOR_LAYOUT" == separate ]]; then
    VENDOR_SEARCH_ROOTS=("$VENDOR_MOUNT_ROOT")
  else
    VENDOR_SEARCH_ROOTS=(
      "$VENDOR_MOUNT_ROOT/vendor"
      "$VENDOR_MOUNT_ROOT/system/vendor"
      "$VENDOR_MOUNT_ROOT"
    )
  fi
}

find_vendor_path() {
  local relative_path="$1"
  local candidate
  local destination
  local resolved

  vendor_image_roots
  for candidate in "${VENDOR_SEARCH_ROOTS[@]}"; do
    [[ -d "$candidate" ]] || continue
    destination="$candidate/$relative_path"
    [[ -e "$destination" || -L "$destination" ]] || continue

    if [[ -d "$destination" ]]; then
      resolved="$(realpath -e -- "$destination")" || {
        echo "Missing image directory: $destination" >&2
        return 2
      }
      if [[ "$resolved" != "$destination" ]]; then
        echo "Refusing unsafe image directory: $destination" >&2
        return 2
      fi
    else
      if ! resolved="$(resolve_image_file "$candidate" "$relative_path")"; then
        return 1
      fi
    fi

    printf '%s\n' "$resolved"
    return 0
  done

  return 1
}
