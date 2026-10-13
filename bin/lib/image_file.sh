# In-place patchers need consistent protection from paths supplied by images.
resolve_image_file() {
  local image_root="$1"
  local relative_path="$2"
  local canonical_root
  local destination
  local canonical

  canonical_root="$(realpath -e -- "$image_root")" || {
    echo "Missing image root: $image_root" >&2
    return 1
  }
  destination="$canonical_root/$relative_path"
  canonical="$(realpath -e -- "$destination" 2>/dev/null)" || {
    echo "Missing image file: $destination" >&2
    return 1
  }
  if [[ "$canonical" != "$destination" || ! -f "$canonical" ]]; then
    echo "Refusing unsafe image file: $destination" >&2
    return 1
  fi

  printf '%s\n' "$canonical"
}
