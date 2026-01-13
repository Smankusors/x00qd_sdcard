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
unzip -o "${TARGET_ZIP}" \
  boot.img \
  system.new.dat.br system.new.dat system.patch.dat system.transfer.list \
  vendor.new.dat.br vendor.new.dat vendor.patch.dat vendor.transfer.list \
  || true

if [ -f system.new.dat.br ]; then
  echo "Debrotling system.new.dat.br..."
  brotli --decompress --force system.new.dat.br
fi
if [ -f vendor.new.dat.br ]; then
  echo "Debrotling vendor.new.dat.br..."
  brotli --decompress --force vendor.new.dat.br
fi

echo "Desparsing..."
python3 /root/sdat2img/sdat2img.py system.transfer.list system.new.dat
python3 /root/sdat2img/sdat2img.py vendor.transfer.list vendor.new.dat vendor.img

echo "Cleaning up..."
rm system.new* system.patch.dat system.transfer.list
rm vendor.new* vendor.patch.dat vendor.transfer.list

cd ..

echo "Unpacking boot.img..."
cp work/boot.img Android_boot_image_editor/boot.img
./Android_boot_image_editor/gradlew -p Android_boot_image_editor unpack

echo "Done."
