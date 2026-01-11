#!/bin/bash
# Build u-boot for Asus Zenfone 5 ZE620KL (sdm636)
# Some code are adapted from Alexey Min's build script
set -e

REPO="https://github.com/Smankusors/u-boot"
COMMIT="7d5b1b39332f960353e601a737c748b30691f164"

BOOTIMG_CMDLINE="uboot2nd"
BOOTIMG_DTB=arch/arm/dts/qcom/sdm636-asus-x00qd.dtb
BOOTIMG_OFFSET_BASE="0x00000000"
BOOTIMG_OFFSET_KERNEL="0x00008000"
BOOTIMG_OFFSET_RAMDISK="0x01000000"
BOOTIMG_OFFSET_SECOND="0x00000000"
BOOTIMG_OFFSET_TAGS="0x00000100"
BOOTIMG_PAGESIZE="4096"

TEMPDIR="$(mktemp -d)"
echo "Downloading u-boot source to $TEMPDIR..."
curl -L $REPO/archive/$COMMIT.tar.gz | tar -xzf - -C $TEMPDIR

cd $TEMPDIR/u-boot-$COMMIT
echo "Configuring u-boot..."
make CROSS_COMPILE=aarch64-linux-gnu- O=build qcom_defconfig qcom-downstream.config qcom-sdm660-phone.config qcom-sdm636-x00qd-smankusors.config

echo "Building u-boot..."
make -j$(nproc) CROSS_COMPILE=aarch64-linux-gnu- O=build

echo "Gzipping u-boot-nodtb.bin..."
rm -f build/u-boot-nodtb.bin.gz
gzip -c build/u-boot-nodtb.bin > build/u-boot-nodtb.bin.gz

echo "Appending dtb to u-boot-nodtb.bin.gz..."
cat build/$BOOTIMG_DTB >> build/u-boot-nodtb.bin.gz

getBootImageJSONValue() {
  jq -r "$1" ~/Android_boot_image_editor/build/unzip_boot/boot.json
}

BOOTIMG_OS_VERSION=$(getBootImageJSONValue .info.osVersion)
BOOTIMG_OS_PATCH_LEVEL=$(getBootImageJSONValue .info.osPatchLevel)

echo "Creating boot.img... (os_version=$BOOTIMG_OS_VERSION, os_patch_level=$BOOTIMG_OS_PATCH_LEVEL)"
mkbootimg \
        --kernel build/u-boot-nodtb.bin.gz \
        --ramdisk ~/patch/empty-initramfs.cpio.gz \
        --base $BOOTIMG_OFFSET_BASE \
        --second_offset $BOOTIMG_OFFSET_SECOND \
        --cmdline $BOOTIMG_CMDLINE \
        --kernel_offset $BOOTIMG_OFFSET_KERNEL \
        --ramdisk_offset $BOOTIMG_OFFSET_RAMDISK \
        --tags_offset $BOOTIMG_OFFSET_TAGS \
        --pagesize $BOOTIMG_PAGESIZE \
        --header_version 2 \
        --dtb build/$BOOTIMG_DTB \
        --os_version "$BOOTIMG_OS_VERSION" \
        --os_patch_level "$BOOTIMG_OS_PATCH_LEVEL" \
        -o ~/work/u-boot.img

echo "Cleaning up..."
rm -rf $TEMPDIR

echo "Done. Please flash work/u-boot.img to the boot partition"
