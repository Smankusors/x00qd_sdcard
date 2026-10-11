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

if ! zip_members=$(unzip -Z1 "$TARGET_ZIP"); then
  echo "Error: Unable to read the ROM zip contents."
  exit 1
fi

zip_has_file() {
  printf '%s\n' "$zip_members" | grep -Fqx -- "$1"
}

missing_files=()
for required_file in boot.img system.transfer.list; do
  if ! zip_has_file "$required_file"; then
    missing_files+=("$required_file")
  fi
done

if ! zip_has_file system.new.dat.br && ! zip_has_file system.new.dat; then
  missing_files+=("system.new.dat.br or system.new.dat")
fi

if zip_has_file vendor.new.dat.br || zip_has_file vendor.new.dat || zip_has_file vendor.transfer.list; then
  if ! zip_has_file vendor.transfer.list; then
    missing_files+=("vendor.transfer.list")
  fi
  if ! zip_has_file vendor.new.dat.br && ! zip_has_file vendor.new.dat; then
    missing_files+=("vendor.new.dat.br or vendor.new.dat")
  fi
fi

if ((${#missing_files[@]} > 0)); then
  echo "Error: ROM zip is missing required files:"
  printf '  - %s\n' "${missing_files[@]}"
  exit 1
fi

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
if [ -f vendor.new.dat ]; then
  python3 /root/sdat2img/sdat2img.py vendor.transfer.list vendor.new.dat vendor.img
fi

echo "Cleaning up..."
rm -f \
  system.new* system.patch.dat system.transfer.list \
  vendor.new* vendor.patch.dat vendor.transfer.list

cd ..

echo "Unpacking boot.img..."
cp work/boot.img Android_boot_image_editor/boot.img
./Android_boot_image_editor/gradlew -p Android_boot_image_editor unpack

echo "Done."
