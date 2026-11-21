remove_dtb_fsmgr_flag() {
  local dtb="$1"
  local name="$2"
  local wanted_flag="$3"
  local node="/firmware/android/fstab/$name"
  local flags flag updated_flags=""
  local changed=0
  local -a flag_list

  if ! flags="$(fdtget -t s "$dtb" "$node" fsmgr_flags 2>/dev/null)"; then
    return 0
  fi

  IFS=',' read -r -a flag_list <<< "$flags"
  for flag in "${flag_list[@]}"; do
    flag="${flag//[[:space:]]/}"
    if [[ "$flag" == "$wanted_flag" ]]; then
      changed=1
      continue
    fi
    if [[ -n "$flag" ]]; then
      if [[ -n "$updated_flags" ]]; then
        updated_flags="${updated_flags},"
      fi
      updated_flags+="$flag"
    fi
  done

  if [[ "$changed" -eq 0 ]]; then
    return 0
  fi
  if [[ -n "$updated_flags" ]]; then
    fdtput -t s "$dtb" "$node" fsmgr_flags "$updated_flags"
  else
    fdtput -d "$dtb" "$node" fsmgr_flags
  fi
  echo "Removed fsmgr flag '$wanted_flag' from $node in $dtb."
}

set_dtb_mount_rw() {
  local dtb="$1"
  shift

  local name node fs_type flags token normalized_token updated_flags
  local -a options updated_options

  for name in "$@"; do
    node="/firmware/android/fstab/$name"
    if ! fs_type="$(fdtget -t s "$dtb" "$node" type 2>/dev/null)" || [[ -z "$fs_type" ]]; then
      echo "Error: $node has no source type property in $dtb." >&2
      return 1
    fi

    flags="$(fdtget -t s "$dtb" "$node" mnt_flags 2>/dev/null || true)"
    options=()
    updated_options=("rw")
    if [[ -n "$flags" ]]; then
      IFS=',' read -r -a options <<< "$flags"
    fi

    for token in "${options[@]}"; do
      normalized_token="${token//[[:space:]]/}"
      if [[ "$normalized_token" == "ro" || "$normalized_token" == "rw" ]]; then
        continue
      fi
      updated_options+=("$token")
    done

    updated_flags="$(IFS=,; printf '%s' "${updated_options[*]}")"
    fdtput -t s "$dtb" "$node" mnt_flags "$updated_flags"
    echo "$node: type=$fs_type mnt_flags=$updated_flags"
  done
}

dtb_has_fstab_nodes() {
  local dtb="$1"
  local vendor_layout="$2"
  local name node property
  local -a nodes

  nodes=(system)
  if [[ "$vendor_layout" == "separate" ]]; then
    nodes+=(vendor)
  fi

  for name in "${nodes[@]}"; do
    node="/firmware/android/fstab/$name"
    if ! fdtget -t s "$dtb" "$node" type >/dev/null 2>&1; then
      return 1
    fi
  done

  return 0
}
