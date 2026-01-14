#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "No config provided."
  echo
  echo "Available configs in the config folder:"

  ls -1 "./config"

  exit 1
fi

ln -sf ../config/$1 work/config
source config/$1

echo "Compiling fstab-microsd.dtbo..."
cp patch/fstab-microsd.dtso.template patch/fstab-microsd.dtso
sed -i "s/\[EMMC_ADDR\]/$EMMC_ADDR/g" patch/fstab-microsd.dtso
sed -i "s/\[MICROSD_ADDR\]/$MICROSD_ADDR/g" patch/fstab-microsd.dtso
dtc -@ -I dts -O dtb -o patch/fstab-microsd.dtbo patch/fstab-microsd.dtso

echo "Environment ready."
