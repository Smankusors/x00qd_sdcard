prepare_boot_image_tree() {
  local boot_image_dir="$1"
  local vendor_layout="$2"
  local ramdisk_root="$boot_image_dir/root"
  local patch_tmpdir dtb_source patch_kernel_dtb boot_dtb
  local -a dtbfiles

  if [[ ! -d "$ramdisk_root" ]]; then
    echo "Error: boot ramdisk root not found at $ramdisk_root; run 02_extract_zip.sh first." >&2
    return 1
  fi

  echo "Extracting device trees..."
  patch_tmpdir="$(mktemp -d)"
  if ! cp "$boot_image_dir/kernel" "$patch_tmpdir/kernel"; then
    rm -rf -- "$patch_tmpdir"
    return 1
  fi

  if [[ -s "$boot_image_dir/dtb" ]]; then
    dtb_source="$boot_image_dir/dtb"
    patch_kernel_dtb=0
    echo "Extracting device trees from boot image DTB..."
  else
    dtb_source="$patch_tmpdir/kernel"
    patch_kernel_dtb=1
    echo "Extracting appended device trees from kernel..."
  fi

  if ! python3 extract-dtb/extract_dtb/extract_dtb.py -o "$patch_tmpdir/out" "$dtb_source"; then
    rm -rf -- "$patch_tmpdir"
    return 1
  fi

  shopt -s nullglob
  dtbfiles=("$patch_tmpdir"/out/*.dtb)
  shopt -u nullglob
  if [[ ${#dtbfiles[@]} -eq 0 ]]; then
    echo "Error: no device tree blobs found in $dtb_source." >&2
    rm -rf -- "$patch_tmpdir"
    return 1
  fi

  if ! boot_dtb="$(select_dtb "$patch_tmpdir/out")" || [[ ! -f "$boot_dtb" ]]; then
    echo "Error: unable to select a device tree blob from $patch_tmpdir/out for this board." >&2
    rm -rf -- "$patch_tmpdir"
    return 1
  fi

  echo "Patching selected device tree..."
  if dtb_has_fstab_nodes "$boot_dtb" "$vendor_layout"; then
    if ! fdtoverlay -i "$boot_dtb" -o "$boot_dtb" patch/fstab-microsd.dtbo; then
      rm -rf -- "$patch_tmpdir"
      return 1
    fi
  else
    echo "No compatible fstab entries for VENDOR_LAYOUT=$vendor_layout in $boot_dtb; using the ramdisk fstab."
  fi

  if [[ "$patch_kernel_dtb" -eq 1 ]]; then
    echo "Concatenating device trees..."
    if ! cat "${dtbfiles[@]}" > "$patch_tmpdir/dtb"; then
      rm -rf -- "$patch_tmpdir"
      return 1
    fi

    echo "Appending patched device trees..."
    if ! cat "$patch_tmpdir/out/00_kernel" "$patch_tmpdir/dtb" > "$boot_image_dir/kernel"; then
      rm -rf -- "$patch_tmpdir"
      return 1
    fi
  else
    echo "Updating boot image DTB..."
    if ! cat "${dtbfiles[@]}" > "$boot_image_dir/dtb"; then
      rm -rf -- "$patch_tmpdir"
      return 1
    fi
    rm -f -- "$boot_image_dir"/dtb*.dts
  fi

  rm -rf -- "$patch_tmpdir"
}
