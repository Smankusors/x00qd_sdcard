repack_boot_image() {
  local boot_image_editor="Android_boot_image_editor"
  local packed_boot_image

  echo "Repacking boot.img..."
  cp work/boot.img "$boot_image_editor/boot.img"
  (
    cd "$boot_image_editor"
    ./gradlew pack
  )

  packed_boot_image="$boot_image_editor/boot.img.signed"
  if [[ ! -f "$packed_boot_image" ]]; then
    echo "Error: Android_boot_image_editor did not produce $packed_boot_image." >&2
    return 1
  fi

  cp -- "$packed_boot_image" work/boot.img
}

# Returns 0 when a compatible DTB fstab was patched, 1 when none was found, 2 on error.
set_boot_image_mount_rw() {
  local boot_image_dir="$1"
  local vendor_layout="$2"
  local kernel="$boot_image_dir/kernel"
  local dtb_source="$boot_image_dir/dtb"
  local tmpdir dtb dtb_fstab_found=0
  local -a dtbfiles nodes

  nodes=(system)
  if [[ "$vendor_layout" == "separate" ]]; then
    nodes+=(vendor)
  fi

  if [[ -f "$kernel" ]]; then
    tmpdir="$(mktemp -d)"
    if ! python3 extract-dtb/extract_dtb/extract_dtb.py -o "$tmpdir" "$kernel"; then
      rm -rf -- "$tmpdir"
      return 2
    fi

    shopt -s nullglob
    dtbfiles=("$tmpdir"/*.dtb)
    shopt -u nullglob
    for dtb in "${dtbfiles[@]}"; do
      if dtb_has_fstab_nodes "$dtb" "$vendor_layout"; then
        set_dtb_mount_rw "$dtb" "${nodes[@]}" || {
          rm -rf -- "$tmpdir"
          return 2
        }
        dtb_fstab_found=1
      fi
    done

    if [[ "$dtb_fstab_found" -eq 1 ]]; then
      if ! cat "$tmpdir/00_kernel" "${dtbfiles[@]}" > "$kernel"; then
        rm -rf -- "$tmpdir"
        return 2
      fi
    fi
    rm -rf -- "$tmpdir"
  fi

  if [[ -s "$dtb_source" ]]; then
    tmpdir="$(mktemp -d)"
    if ! python3 extract-dtb/extract_dtb/extract_dtb.py -o "$tmpdir" "$dtb_source"; then
      rm -rf -- "$tmpdir"
      return 2
    fi

    if dtb="$(select_dtb "$tmpdir")" && [[ -f "$dtb" ]] &&
      dtb_has_fstab_nodes "$dtb" "$vendor_layout"; then
      set_dtb_mount_rw "$dtb" "${nodes[@]}" || {
        rm -rf -- "$tmpdir"
        return 2
      }
      if ! cp -- "$dtb" "$dtb_source"; then
        rm -rf -- "$tmpdir"
        return 2
      fi
      dtb_fstab_found=1
    fi
    rm -rf -- "$tmpdir"
  fi

  if [[ "$dtb_fstab_found" -eq 1 ]]; then
    return 0
  fi
  return 1
}
