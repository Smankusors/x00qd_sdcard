#!/usr/bin/env python3
"""Convert an RSA PEM key to Android legacy dm-verity's mincrypt /verity_key format."""

import argparse
import os
import struct
import subprocess
import tempfile


WORD_COUNT = 64
KEY_BYTES = WORD_COUNT * 4


def read_der_value(data, offset):
    tag = data[offset]
    offset += 1
    first_length = data[offset]
    offset += 1
    if first_length < 0x80:
        length = first_length
    else:
        length_bytes = first_length & 0x7F
        if not length_bytes or length_bytes > 4:
            raise ValueError("invalid DER length")
        length = int.from_bytes(data[offset : offset + length_bytes], "big")
        offset += length_bytes
    end = offset + length
    if end > len(data):
        raise ValueError("truncated DER value")
    return tag, data[offset:end], end


def rsa_numbers_from_spki(data):
    tag, outer, end = read_der_value(data, 0)
    if tag != 0x30 or end != len(data):
        raise ValueError("invalid SubjectPublicKeyInfo")
    tag, _, offset = read_der_value(outer, 0)  # AlgorithmIdentifier.
    if tag != 0x30:
        raise ValueError("missing RSA AlgorithmIdentifier")
    tag, bit_string, offset = read_der_value(outer, offset)
    if tag != 0x03 or not bit_string or bit_string[0] != 0:
        raise ValueError("invalid SubjectPublicKeyInfo bit string")
    tag, rsa_sequence, end = read_der_value(bit_string, 1)
    if tag != 0x30 or end != len(bit_string):
        raise ValueError("invalid RSA public key sequence")
    tag, modulus_bytes, offset = read_der_value(rsa_sequence, 0)
    if tag != 0x02:
        raise ValueError("missing RSA modulus")
    tag, exponent_bytes, offset = read_der_value(rsa_sequence, offset)
    if tag != 0x02 or offset != len(rsa_sequence):
        raise ValueError("missing RSA exponent")
    return int.from_bytes(modulus_bytes, "big"), int.from_bytes(exponent_bytes, "big")


def words_le(value):
    return [(value >> (32 * i)) & 0xFFFFFFFF for i in range(WORD_COUNT)]


def encode_mincrypt_key(modulus, exponent):
    if modulus.bit_length() != WORD_COUNT * 32:
        raise ValueError("legacy Android verity keys must be RSA-2048")
    if exponent < 3 or exponent > 0xFFFFFFFF or exponent % 2 == 0:
        raise ValueError("RSA exponent is not supported by mincrypt")

    radix = 1 << (WORD_COUNT * 32)
    n0inv = (-pow(modulus, -1, 1 << 32)) & 0xFFFFFFFF
    rr = pow(radix, 2, modulus)
    return struct.pack(
        "<II64I64II",
        WORD_COUNT,
        n0inv,
        *words_le(modulus),
        *words_le(rr),
        exponent,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("public_pem", help="OpenSSL SubjectPublicKeyInfo PEM")
    parser.add_argument("output", help="Android legacy dm-verity /verity_key blob output path")
    args = parser.parse_args()

    der = subprocess.run(
        ["openssl", "pkey", "-pubin", "-in", args.public_pem, "-outform", "DER"],
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    modulus, exponent = rsa_numbers_from_spki(der)
    encoded = encode_mincrypt_key(modulus, exponent)
    if len(encoded) != 8 + 2 * KEY_BYTES + 4:
        raise ValueError("unexpected Android public key encoding size")

    output_dir = os.path.dirname(os.path.abspath(args.output))
    os.makedirs(output_dir, exist_ok=True)
    fd, temporary_path = tempfile.mkstemp(prefix=".verity_key.", dir=output_dir)
    try:
        with os.fdopen(fd, "wb") as output_file:
            output_file.write(encoded)
        os.chmod(temporary_path, 0o644)
        os.replace(temporary_path, args.output)
    except BaseException:
        try:
            os.unlink(temporary_path)
        except FileNotFoundError:
            pass
        raise


if __name__ == "__main__":
    main()
