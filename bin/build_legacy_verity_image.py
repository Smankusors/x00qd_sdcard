#!/usr/bin/env python3
"""Build an Android legacy dm-verity image from a raw ext4 system image."""

import argparse
import hashlib
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile


BLOCK_SIZE = 4096
HASH_SIZE = 32
HASHES_PER_BLOCK = BLOCK_SIZE // HASH_SIZE
METADATA_SIZE = 8 * BLOCK_SIZE
VERITY_MAGIC = 0xB001B001
VERITY_VERSION = 0
# AOSP Android 9 legacy Verified Boot 1.0 FIXED_SALT, retained in later AOSP:
# https://android.googlesource.com/platform/build/+/android-9.0.0_r8/tools/releasetools/verity_utils.py
FIXED_SALT = bytes.fromhex(
    "aee087a5be3b982978c923f566a94613496b417f2af592639bc80d141e34dfe7"
)


def run(command, accepted_codes=(0,)):
    result = subprocess.run(command, check=False)
    if result.returncode not in accepted_codes:
        raise RuntimeError(
            "command failed ({}): {}".format(
                result.returncode, " ".join(str(part) for part in command)
            )
        )


def ext4_info(path):
    with open(path, "rb") as image:
        image.seek(1024)
        superblock = image.read(1024)
    if len(superblock) != 1024 or struct.unpack_from("<H", superblock, 56)[0] != 0xEF53:
        raise ValueError("{} is not an ext4 image".format(path))

    block_size = 1024 << struct.unpack_from("<I", superblock, 24)[0]
    if block_size != BLOCK_SIZE:
        raise ValueError("Android legacy verity requires 4096-byte ext4 blocks")

    blocks = struct.unpack_from("<I", superblock, 4)[0]
    incompat = struct.unpack_from("<I", superblock, 96)[0]
    if incompat & 0x80:  # EXT4_FEATURE_INCOMPAT_64BIT
        blocks |= struct.unpack_from("<I", superblock, 336)[0] << 32
    return blocks, block_size


def tree_blocks(data_blocks):
    level_blocks = (data_blocks + HASHES_PER_BLOCK - 1) // HASHES_PER_BLOCK
    total = 0
    while True:
        total += level_blocks
        if level_blocks == 1:
            return total
        level_blocks = (level_blocks + HASHES_PER_BLOCK - 1) // HASHES_PER_BLOCK


def max_data_blocks(partition_blocks):
    low, high = 1, partition_blocks
    while low < high:
        middle = (low + high + 1) // 2
        required = middle + tree_blocks(middle) + METADATA_SIZE // BLOCK_SIZE
        if required <= partition_blocks:
            low = middle
        else:
            high = middle - 1
    return low


def build_tree(data_path, tree_path, data_blocks):
    levels = []
    hashes = bytearray()
    with open(data_path, "rb") as data:
        for _ in range(data_blocks):
            block = data.read(BLOCK_SIZE)
            if len(block) != BLOCK_SIZE:
                raise ValueError("filesystem image ended before its ext4 block count")
            hashes.extend(hashlib.sha256(FIXED_SALT + block).digest())

    hashes.extend(b"\0" * ((-len(hashes)) % BLOCK_SIZE))
    levels.append(hashes)
    while len(levels[-1]) > BLOCK_SIZE:
        previous = levels[-1]
        next_level = bytearray()
        for offset in range(0, len(previous), BLOCK_SIZE):
            next_level.extend(
                hashlib.sha256(FIXED_SALT + previous[offset : offset + BLOCK_SIZE]).digest()
            )
        next_level.extend(b"\0" * ((-len(next_level)) % BLOCK_SIZE))
        levels.append(next_level)

    if len(levels[-1]) != BLOCK_SIZE:
        raise ValueError("invalid dm-verity tree root level")
    root_hash = hashlib.sha256(FIXED_SALT + levels[-1]).hexdigest()
    with open(tree_path, "wb") as tree:
        for level in reversed(levels):
            tree.write(level)
    return root_hash


def build_metadata(root_hash, data_blocks, block_device, signing_key, output_path):
    table = (
        "1 {} {} {} {} {} {} sha256 {} {}".format(
            block_device,
            block_device,
            BLOCK_SIZE,
            BLOCK_SIZE,
            data_blocks,
            data_blocks,
            root_hash,
            FIXED_SALT.hex(),
        )
    ).encode("ascii")

    with tempfile.TemporaryDirectory(prefix="legacy-verity-sign-") as temporary_dir:
        table_path = Path(temporary_dir) / "verity.table"
        signature_path = Path(temporary_dir) / "verity.signature"
        table_path.write_bytes(table)
        run(
            [
                "openssl",
                "dgst",
                "-sha256",
                "-sign",
                str(signing_key),
                "-out",
                str(signature_path),
                str(table_path),
            ]
        )
        signature = signature_path.read_bytes()

    if len(signature) != 256:
        raise ValueError("legacy Android verity expects an RSA-2048 table signature")
    header = struct.pack("<II256sI", VERITY_MAGIC, VERITY_VERSION, signature, len(table))
    metadata = (header + table).ljust(METADATA_SIZE, b"\0")
    Path(output_path).write_bytes(metadata)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--partition-size", required=True, type=int)
    parser.add_argument("--block-device", required=True)
    parser.add_argument("--signing-key", required=True, type=Path)
    args = parser.parse_args()

    if args.partition_size <= 0 or args.partition_size % BLOCK_SIZE:
        raise ValueError("partition size must be a positive multiple of 4096")
    if not args.image.is_file() or not args.signing_key.is_file():
        raise ValueError("system image or signing key is missing")
    if args.image.stat().st_size != args.partition_size:
        raise ValueError("system image size does not match the configured partition size")
    if args.output.resolve() == args.image.resolve():
        raise ValueError("output must not overwrite the input image")

    partition_blocks = args.partition_size // BLOCK_SIZE
    target_data_blocks = max_data_blocks(partition_blocks)
    target_size = target_data_blocks * BLOCK_SIZE
    expected_tree_size = tree_blocks(target_data_blocks) * BLOCK_SIZE
    if target_size + expected_tree_size + METADATA_SIZE > args.partition_size:
        raise ValueError("verity data does not fit in the configured partition")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="system-verity-", dir=args.output.parent) as temp_dir:
        temp_image = Path(temp_dir) / "system.ext4"
        temp_tree = Path(temp_dir) / "verity.tree"
        temp_metadata = Path(temp_dir) / "verity.metadata"
        shutil.copyfile(args.image, temp_image)

        run(["e2fsck", "-f", "-p", str(temp_image)], accepted_codes=(0, 1, 2, 3))
        run(["resize2fs", str(temp_image), str(target_data_blocks)])
        run(["e2fsck", "-f", "-p", str(temp_image)], accepted_codes=(0, 1, 2, 3))

        actual_blocks, _ = ext4_info(temp_image)
        if actual_blocks != target_data_blocks:
            raise ValueError(
                "resize2fs produced {} blocks; expected {}".format(
                    actual_blocks, target_data_blocks
                )
            )
        os.truncate(temp_image, target_size)

        root_hash = build_tree(temp_image, temp_tree, target_data_blocks)
        if temp_tree.stat().st_size != expected_tree_size:
            raise ValueError("generated hash tree has an unexpected size")
        build_metadata(
            root_hash,
            target_data_blocks,
            args.block_device,
            args.signing_key,
            temp_metadata,
        )

        with open(temp_image, "ab") as image, open(temp_tree, "rb") as tree:
            shutil.copyfileobj(tree, image)
            with open(temp_metadata, "rb") as metadata:
                shutil.copyfileobj(metadata, image)
            image.truncate(args.partition_size)

        if temp_image.stat().st_size != args.partition_size:
            raise ValueError("generated image does not match partition size")
        os.replace(temp_image, args.output)

    print("Legacy dm-verity image: {}".format(args.output))
    print("Data blocks: {}".format(target_data_blocks))
    print("Hash tree bytes: {}".format(expected_tree_size))
    print("Metadata bytes: {}".format(METADATA_SIZE))
    print("Root hash: {}".format(root_hash))
    print("Salt: {}".format(FIXED_SALT.hex()))


if __name__ == "__main__":
    main()
