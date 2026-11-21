LEGACY_DM_VERITY_KEY_DIR="work/legacy-dm-verity"
LEGACY_DM_VERITY_PRIVATE_KEY="$LEGACY_DM_VERITY_KEY_DIR/legacy_dm_verity_private.pem"
LEGACY_DM_VERITY_PUBLIC_KEY="$LEGACY_DM_VERITY_KEY_DIR/legacy_dm_verity_public.pem"
LEGACY_DM_VERITY_KEY_BLOB="$LEGACY_DM_VERITY_KEY_DIR/legacy_dm_verity_key"

prepare_legacy_dm_verity_for_boot() {
  local boot_image_dir="$1"
  local system_fsmgr_flags
  local system_verity_mode

  system_fsmgr_flags="$(get_system_fsmgr_flags "$boot_image_dir")"
  system_verity_mode="$(system_verity_mode_from_flags "$system_fsmgr_flags")"
  if [[ "$system_verity_mode" != legacy ]]; then
    echo "System fsmgr_flags='${system_fsmgr_flags:-<empty>}' ($system_verity_mode); skipping legacy dm-verity key generation."
    return 0
  fi

  if [[ ! -d "$boot_image_dir/root" ]]; then
    echo "Error: boot ramdisk root not found at $boot_image_dir/root; run 02_extract_zip.sh first." >&2
    return 1
  fi

  mkdir -p "$LEGACY_DM_VERITY_KEY_DIR"
  (
    umask 077
    echo "Generating legacy dm-verity RSA keypair..."
    openssl genpkey \
      -algorithm RSA \
      -pkeyopt rsa_keygen_bits:2048 \
      -out "$LEGACY_DM_VERITY_PRIVATE_KEY"
    openssl pkey \
      -in "$LEGACY_DM_VERITY_PRIVATE_KEY" \
      -pubout \
      -out "$LEGACY_DM_VERITY_PUBLIC_KEY"
    python3 bin/generate_android_verity_key.py \
      "$LEGACY_DM_VERITY_PUBLIC_KEY" \
      "$LEGACY_DM_VERITY_KEY_BLOB"
    chmod 600 "$LEGACY_DM_VERITY_PRIVATE_KEY" "$LEGACY_DM_VERITY_PUBLIC_KEY"
    chmod 644 "$LEGACY_DM_VERITY_KEY_BLOB"
  )

  install -m 0644 "$LEGACY_DM_VERITY_KEY_BLOB" "$boot_image_dir/root/verity_key"
}
