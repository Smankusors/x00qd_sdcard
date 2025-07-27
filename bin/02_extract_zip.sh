#!/bin/bash
set -e

cd work

zip_files=($(find . -maxdepth 1 -name "*.zip"))
if [ ${#zip_files[@]} -eq 0 ]; then
  echo "Error: No zip files found in the work folder."
  exit 1
elif [ ${#zip_files[@]} -gt 1 ]; then
  echo "Error: Multiple zip files found! Please ensure there's only one zip file in the work folder."
  exit 1
fi
TARGET_ZIP="${zip_files[0]}"

echo "Unzipping..."
unzip -o "${TARGET_ZIP}" boot.img system.new.dat.br system.patch.dat system.transfer.list vendor.new.dat.br vendor.patch.dat vendor.transfer.list

echo "Debrotling..."
brotli --decompress --force system.new.dat.br
brotli --decompress --force vendor.new.dat.br

echo "Desparsing..."
python3 /root/sdat2img/sdat2img.py system.transfer.list system.new.dat
python3 /root/sdat2img/sdat2img.py vendor.transfer.list vendor.new.dat vendor.img

echo "Cleaning up..."
rm system.new* system.patch.dat system.transfer.list
rm vendor.new* vendor.patch.dat vendor.transfer.list

echo "Done."
