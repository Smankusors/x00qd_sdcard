# Android on µSD for X00QD

- [Disclaimer](#disclaimer)
- [Compatibility](#compatibility)
- [Background](#background)
- [Important Notes](#important-notes)
- [Requirements](#requirements)
- [Preparation](#preparation)
- [Procedures](#procedures)
  - [0. Put the ROM zip to the work folder](#0-put-the-rom-zip-to-the-work-folder)
  - [1. Prepare the sdcard](#1-prepare-the-sdcard)
  - [2. Extract zip](#2-extract-zip)
  - [3. Format data](#3-format-data)
  - [4. Patch boot.img or write extlinux boot config](#4-patch-bootimg-or-write-extlinux-boot-config)
    - [Patch boot.img (stock bootloader)](#patch-bootimg-stock-bootloader)
    - [Or write extlinux config (U-Boot or other bootloaders)](#or-write-extlinux-config-u-boot-or-other-bootloaders)
  - [5. Patch vendor image](#5-patch-vendor-image)
  - [6. Write system and vendor images to sdcard](#6-write-system-and-vendor-images-to-sdcard)
  - [7. Flash modified boot.img to the phone](#7-flash-modified-bootimg-to-the-phone)
- [U-Boot Bootloader](#u-boot-bootloader)
- [Acknowledgements](#acknowledgements)

## Disclaimer

> [!WARNING]
> **Proceed at your own risk!**
>
> This project comes with no warranty. While the steps have been tested, I can't guarantee it will work perfectly for everyone. If something goes wrong and your phone or microSD card gets damaged, I am not responsible. **Always back up your important data before starting**, and double-check everything carefully.

## Compatibility

This project is designed for the **Asus X00QD**, which features the Qualcomm Snapdragon 636 (SDM636) chipset. However, it could potentially work on other devices with similar SoCs, such as those based on **SDM630**, **SDM636**, or **SDM660** chipsets. Your mileage may vary.

Currently, it doesn't work with stock ROMs. I have no idea why, and I have no plan to support it too.

## Background

Because I was itching to try out the new Android without freaking out about my data, plus having a quick "undo" button seemed smart. Also, I'm kinda paranoid about wearing out my flash memory, and hey, it's way easier to swap out a microSD if things go sideways.

Though, I ended up losing all of my data twice. 😭

## Important Notes

> [!IMPORTANT]
>
> **If you want to boot with a different microSD card in the future**, make sure to **disable or remove the lock screen (PIN, password, or pattern)** before switching. Otherwise, you may be unable to unlock the phone, and you could lose access to your data entirely.
>
> **Always back up your data** before making any changes to avoid potential data loss.

## Requirements

To set up this environment, you'll need:

1. **Unlocked bootloader**
2. **microSD card** with at least an A1 class rating *(Class 10 cards are supported but god bless your patience)*
3. **10GB of free storage** on the host machine
4. **3GB of free RAM** on the host machine *(some steps rely on Java-based tools)*
5. **GNU/Linux OS** on the host machine *(or WSL with [usbipd-win](https://github.com/dorssel/usbipd-win) for USB access)*
6. **Docker** on the host machine

If you don't have any PCs... I guess you could use other phone with root and without Docker, but you are on your own. 😉

## Preparation

Before you begin, you need to prepare the environment first. If you use HDD, well god bless your patience, it could take up to 30 minutes, at least that's on my poor laptop HDD.

```
git clone https://github.com/Smankusors/x00qd_sdcard
cd x00qd_sdcard
docker compose build
```

## Procedures

### 0. Put the ROM zip to the work folder

Ensure the ROM zip contains the following files:

* boot.img
* system.new.dat.br
* vendor.new.dat.br

### 1. Prepare the sdcard

Run the following command, replacing /dev/sdX with your microSD card's device path.

⚠️ Be careful not to select the wrong disk to avoid data loss.

```
./runInDocker.sh 01_prepare_sdcard.sh /dev/sdX
```

### 2. Extract zip

```
./runInDocker.sh 02_extract_zip.sh
```

### 3. Format data

```
./runInDocker.sh 03_format_data.sh /dev/sdX ext4
```

or

```
./runInDocker.sh 03_format_data.sh /dev/sdX f2fs
```

### 4. Patch boot.img or write extlinux boot config

Choose boot method:

#### Patch boot.img (stock bootloader)

```
./runInDocker.sh 04_patch_boot.sh
```

#### Or write extlinux config (U-Boot or other bootloaders)

```
./runInDocker.sh 04_write_extlinux_boot_config.sh /dev/sdX
```

### 5. Patch vendor image

```
./runInDocker.sh 05_patch_vendor.sh
```

### 6. Write system and vendor images to sdcard

```
./runInDocker.sh 06_write_sdcard.sh /dev/sdX
```

### 7. Flash modified boot.img to the phone

```
fastboot flash boot work/boot.img
fastboot reboot
```

That's it! Now you can enjoy Android on your microSD card without fear of bricking your phone or overloading the internal storage. 😉

## U-Boot Bootloader

If you want to multi-boot with postmarketOS with just swapping the microSD, you can opt to use U-Boot bootloader instead of the stock one.

> [!IMPORTANT]
> For encrypted storage to work, U-Boot's boot.img metadata must match the installed Android OS. For more information, please check [Android Keymaster Issue on Qualcomm Devices](https://wiki.postmarketos.org/wiki/Category:Bootloaders/Keymaster)

To build U-Boot bootloader, you need to run `02_extract_zip.sh` first to extract the boot.img metadata, and then you can just build with this simple command:

```
./runInDocker.sh 07_build_uboot.sh
```

It will compile and generate `work/u-boot.img` file that you can flash to your phone with:

```
fastboot flash boot work/u-boot.img
fastboot reboot
```

To get U-Boot to automatically boot Android from the microSD, we can replace step 4 of patching boot.img with writing extlinux boot config to the cache partition of the microSD card:

```
./runInDocker.sh 04_write_extlinux_boot_config.sh /dev/sdX
```

## Acknowledgements

Thanks for these projects that makes this project possible 🙏

- https://github.com/xpirt/sdat2img
- https://github.com/cfig/Android_boot_image_editor
- https://github.com/PabloCastellano/extract-dtb
- https://github.com/sdm660-mainline/u-boot
