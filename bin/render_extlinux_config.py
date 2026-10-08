#!/usr/bin/env python3
"""Render boot metadata into the extlinux configuration template."""

import argparse
import json
from pathlib import Path


class Arguments(argparse.Namespace):
    boot_json: Path
    extlinux_config: Path
    fdt_overlays: str


def single_line_cmdline(value: object) -> str:
    if not isinstance(value, str):
        raise ValueError("boot metadata has no string command line")
    if "\0" in value:
        raise ValueError("boot command line cannot contain NUL bytes")

    return value.replace("\r\n", " ").replace("\r", " ").replace("\n", " ")


def replace_placeholder(config: str, placeholder: str, value: str) -> str:
    if config.count(placeholder) != 1:
        raise ValueError(f"expected exactly one {placeholder} placeholder")
    return config.replace(placeholder, value)


def parse_args() -> Arguments:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("boot_json", type=Path)
    parser.add_argument("extlinux_config", type=Path)
    parser.add_argument("fdt_overlays")

    args = Arguments()
    parser.parse_args(namespace=args)
    return args


def main() -> None:
    args = parse_args()

    with args.boot_json.open(encoding="utf-8") as boot_json_file:
        boot: object = json.load(boot_json_file)

    info = boot.get("info") if isinstance(boot, dict) else None
    cmdline = single_line_cmdline(info.get("cmdline") if isinstance(info, dict) else None)

    config = args.extlinux_config.read_text(encoding="utf-8")
    config = replace_placeholder(config, "[CMDLINE]", cmdline)
    config = replace_placeholder(config, "[FDTOVERLAYS]", args.fdt_overlays)
    args.extlinux_config.write_text(config, encoding="utf-8")
    print(f"CMDLINE={cmdline!r}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        raise SystemExit(f"Error: {error}") from error
