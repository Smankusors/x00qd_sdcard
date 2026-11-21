get_system_fsmgr_flags() (
  set -e

  local boot_image_dir="$1"
  local dtb_source=""
  local temporary_dir=""
  local selected_dtb=""
  local flags=""
  local fstab

  if [[ -s "$boot_image_dir/dtb" ]]; then
    dtb_source="$boot_image_dir/dtb"
  elif [[ -f "$boot_image_dir/kernel" ]]; then
    dtb_source="$boot_image_dir/kernel"
  fi

  if [[ -n "$dtb_source" ]]; then
    temporary_dir="$(mktemp -d)"
    trap 'rm -rf -- "$temporary_dir"' EXIT
    python3 extract-dtb/extract_dtb/extract_dtb.py -o "$temporary_dir" "$dtb_source"

    if selected_dtb="$(select_dtb "$temporary_dir")" && [[ -f "$selected_dtb" ]] &&
      fdtget -t s "$selected_dtb" /firmware/android/fstab/system compatible >/dev/null 2>&1; then
      fdtget -t s "$selected_dtb" /firmware/android/fstab/system fsmgr_flags 2>/dev/null || true
      exit 0
    fi
  fi

  # Some devices keep the active fstab in the ramdisk instead of the DT.
  while IFS= read -r -d '' fstab; do
    flags="$(awk '$2 == "/system" { print $5; exit }' "$fstab")"
    if [[ -n "$flags" ]]; then
      printf '%s\n' "$flags"
      exit 0
    fi
  done < <(find "$boot_image_dir/root" -type f -name 'fstab*' ! -iname '*recovery*' -print0)

  echo "Error: unable to determine system fsmgr_flags from the boot DT or ramdisk." >&2
  exit 1
)

fs_mgr_flag_present() {
  local flags="$1"
  local wanted="$2"
  local flag
  local -a flag_list

  IFS=',' read -r -a flag_list <<< "$flags"
  for flag in "${flag_list[@]}"; do
    flag="${flag//[[:space:]]/}"
    if [[ "$flag" == "$wanted" ]]; then
      return 0
    fi
  done
  return 1
}

system_verity_mode_from_flags() {
  local flags="$1"

  if fs_mgr_flag_present "$flags" avb; then
    printf 'avb\n'
  elif fs_mgr_flag_present "$flags" verifyatboot; then
    printf 'verifyatboot\n'
  elif fs_mgr_flag_present "$flags" verify; then
    printf 'legacy\n'
  else
    printf 'none\n'
  fi
}
