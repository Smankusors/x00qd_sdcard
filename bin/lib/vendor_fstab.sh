replace_fstab_device_paths() {
  local fstab="$1"
  local original_fstab_snapshot
  local cmp_status
  local escaped_emmc_by_name_path
  local escaped_microsd_device_path

  original_fstab_snapshot="$(mktemp)"
  if ! cp -- "$fstab" "$original_fstab_snapshot"; then
    rm -f -- "$original_fstab_snapshot"
    return 1
  fi

  escaped_emmc_by_name_path="${FSTAB_EMMC_BY_NAME_PATH//./\\.}"
  escaped_microsd_device_path="${MICROSD_DEVICE_PATH//./\\.}"
  if ! sed -i "\\#$escaped_microsd_device_path#d" "$fstab" ||
    ! sed -i "s#$escaped_emmc_by_name_path/userdata#${MICROSD_DEVICE_PATH}/by-name/microsd_userdata#g" "$fstab" ||
    ! sed -i "s#$escaped_emmc_by_name_path/cache#${MICROSD_DEVICE_PATH}/by-name/microsd_cache#g" "$fstab" ||
    ! sed -i "s#$escaped_emmc_by_name_path/system#${MICROSD_DEVICE_PATH}/by-name/microsd_system#g" "$fstab" ||
    ! sed -i "s#$escaped_emmc_by_name_path/vendor#${MICROSD_DEVICE_PATH}/by-name/microsd_vendor#g" "$fstab"; then
    rm -f -- "$original_fstab_snapshot"
    return 1
  fi

  if cmp -s -- "$original_fstab_snapshot" "$fstab"; then
    echo "Warning: fstab was unchanged after patching: $fstab" >&2
  else
    cmp_status=$?
    if [[ "$cmp_status" -ne 1 ]]; then
      rm -f -- "$original_fstab_snapshot"
      return 1
    fi
  fi
  rm -f -- "$original_fstab_snapshot"
}

find_ramdisk_fstab_files() {
  find "$1" -type f -name 'fstab*' ! -iname '*recovery*' -print0
}

set_fstab_mount_rw_entry() {
  local fstab="$1"
  local partition="$2"

  sed -E -i \
    -e "/\\/by-name\\/microsd_${partition}(_[ab])?[[:space:]]+\\/${partition}[[:space:]]/s/(^|,)ro(,|[[:space:]]|\$)/\\1rw\\2/g" \
    "$fstab"
}

set_fstab_mount_rw() {
  local fstab="$1"
  local vendor_layout="$2"
  local tmpfile

  tmpfile="$(mktemp)"
  if ! cp -- "$fstab" "$tmpfile"; then
    rm -f -- "$tmpfile"
    return 1
  fi
  if ! set_fstab_mount_rw_entry "$tmpfile" system; then
    rm -f -- "$tmpfile"
    return 1
  fi
  if [[ "$vendor_layout" == "separate" ]] && ! set_fstab_mount_rw_entry "$tmpfile" vendor; then
    rm -f -- "$tmpfile"
    return 1
  fi

  if ! cat -- "$tmpfile" > "$fstab"; then
    rm -f -- "$tmpfile"
    return 1
  fi
  rm -f -- "$tmpfile"
}
