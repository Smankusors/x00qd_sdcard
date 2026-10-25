#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "No config provided."
  echo
  echo "Available configs in the config folder:"

  ls -1 "./config"

  exit 1
fi

CONFIG_FILE="config/$1"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: $CONFIG_FILE does not exist."
  exit 1
fi

source "$CONFIG_FILE"

is_positive_decimal_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

if ! is_positive_decimal_integer "${BOARD_BOOTIMAGE_PARTITION_SIZE:-}"; then
  echo "Error: $CONFIG_FILE must set a positive decimal integer for BOARD_BOOTIMAGE_PARTITION_SIZE."
  exit 1
fi
if ! is_positive_decimal_integer "${BOARD_CACHEIMAGE_PARTITION_SIZE:-}"; then
  echo "Error: $CONFIG_FILE must set a positive decimal integer for BOARD_CACHEIMAGE_PARTITION_SIZE."
  exit 1
fi
if ! is_positive_decimal_integer "${BOARD_SYSTEMIMAGE_PARTITION_SIZE:-}"; then
  echo "Error: $CONFIG_FILE must set a positive decimal integer for BOARD_SYSTEMIMAGE_PARTITION_SIZE."
  exit 1
fi

if [[ -n "${BOARD_VENDORIMAGE_PARTITION_SIZE:-}" && ! "${BOARD_VENDORIMAGE_PARTITION_SIZE}" =~ ^(0|[1-9][0-9]*)$ ]]; then
  echo "Error: $CONFIG_FILE must set BOARD_VENDORIMAGE_PARTITION_SIZE to a non-negative decimal integer."
  exit 1
fi

if [[ -z "${EMMC_DEVICE_PATH:-}" ]]; then
  echo "Error: $CONFIG_FILE must set EMMC_DEVICE_PATH."
  exit 1
fi
if [[ -z "${MICROSD_DEVICE_PATH:-}" ]]; then
  echo "Error: $CONFIG_FILE must set MICROSD_DEVICE_PATH."
  exit 1
fi
if [[ -z "${FSTAB_EMMC_BY_NAME_PATH:-}" ]]; then
  echo "Error: $CONFIG_FILE must set FSTAB_EMMC_BY_NAME_PATH."
  exit 1
fi

case "${VENDOR_LAYOUT:-}" in
  separate)
    if ! is_positive_decimal_integer "${BOARD_VENDORIMAGE_PARTITION_SIZE:-}"; then
      echo "Error: VENDOR_LAYOUT=separate requires a positive BOARD_VENDORIMAGE_PARTITION_SIZE."
      exit 1
    fi
    FSTAB_TEMPLATE="patch/fstab-microsd-vendor-separate.dtso.template"
    ;;
  system)
    if [[ "${BOARD_VENDORIMAGE_PARTITION_SIZE:-0}" =~ [1-9] ]]; then
      echo "Error: VENDOR_LAYOUT=$VENDOR_LAYOUT cannot have a separate vendor partition size."
      exit 1
    fi
    FSTAB_TEMPLATE="patch/fstab-microsd-vendor-not-separate.dtso.template"
    ;;
  *)
    echo "Error: config/$1 must set VENDOR_LAYOUT to separate or system."
    exit 1
    ;;
esac

ln -sf ../config/$1 work/config

echo "Compiling fstab-microsd.dtbo..."
cp "$FSTAB_TEMPLATE" patch/fstab-microsd.dtso
sed -i "s|\[EMMC_DEVICE_PATH\]|$EMMC_DEVICE_PATH|g" patch/fstab-microsd.dtso
sed -i "s|\[MICROSD_DEVICE_PATH\]|$MICROSD_DEVICE_PATH|g" patch/fstab-microsd.dtso
dtc -@ -I dts -O dtb -o patch/fstab-microsd.dtbo patch/fstab-microsd.dtso

echo "Environment ready."
