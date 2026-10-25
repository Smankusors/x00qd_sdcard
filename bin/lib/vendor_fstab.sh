replace_fstab_device_paths() {
  local fstab="$1"

  sed -i "/$MICROSD_ADDR/d" "$fstab"
  sed -i "s/\/dev\/block\/bootdevice\/by-name\/userdata/\/dev\/block\/platform\/soc\/$MICROSD_ADDR\/by-name\/microsd_userdata/g" "$fstab"
  sed -i "s/\/dev\/block\/bootdevice\/by-name\/cache/\/dev\/block\/platform\/soc\/$MICROSD_ADDR\/by-name\/microsd_cache/g" "$fstab"
  sed -i "s/\/dev\/block\/bootdevice\/by-name\/system/\/dev\/block\/platform\/soc\/$MICROSD_ADDR\/by-name\/microsd_system/g" "$fstab"
  sed -i "s/\/dev\/block\/bootdevice\/by-name\/vendor/\/dev\/block\/platform\/soc\/$MICROSD_ADDR\/by-name\/microsd_vendor/g" "$fstab"
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
  RAMDISK_FSTAB_CHANGED=1
  rm -f -- "$tmpfile"
}
