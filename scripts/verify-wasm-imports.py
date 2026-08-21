#!/usr/bin/env python3
"""Reject accidental C-runtime imports in the linked PQ core WebAssembly."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

FORBIDDEN = {"malloc", "free", "exit", "memcpy", "memset", "memmove", "memcmp"}
FORBIDDEN_PAYLOADS = {b"rwa-vault-pq-core: fatal"}


class WasmReader:
    def __init__(self, data: bytes) -> None:
        self.data = data
        self.offset = 0

    def byte(self) -> int:
        if self.offset >= len(self.data):
            raise ValueError("unexpected end of WebAssembly module")
        value = self.data[self.offset]
        self.offset += 1
        return value

    def uleb(self) -> int:
        value = 0
        shift = 0
        while True:
            byte = self.byte()
            value |= (byte & 0x7F) << shift
            if byte & 0x80 == 0:
                return value
            shift += 7
            if shift > 63:
                raise ValueError("invalid unsigned LEB128 integer")

    def name(self) -> str:
        length = self.uleb()
        end = self.offset + length
        if end > len(self.data):
            raise ValueError("truncated WebAssembly name")
        value = self.data[self.offset:end].decode("utf-8")
        self.offset = end
        return value

    def subreader(self, length: int) -> "WasmReader":
        end = self.offset + length
        if end > len(self.data):
            raise ValueError("truncated WebAssembly section")
        reader = WasmReader(self.data[self.offset:end])
        self.offset = end
        return reader


def skip_limits(reader: WasmReader) -> None:
    flags = reader.uleb()
    reader.uleb()
    if flags & 0x01:
        reader.uleb()


def imports_from(module: bytes) -> list[tuple[str, str]]:
    reader = WasmReader(module)
    if reader.data[:8] != b"\0asm\x01\0\0\0":
        raise ValueError("not a WebAssembly 1.0 module")
    reader.offset = 8
    imports: list[tuple[str, str]] = []

    while reader.offset < len(reader.data):
        section_id = reader.byte()
        section = reader.subreader(reader.uleb())
        if section_id != 2:
            continue

        for _ in range(section.uleb()):
            namespace = section.name()
            name = section.name()
            kind = section.byte()
            imports.append((namespace, name))
            if kind == 0:  # function
                section.uleb()
            elif kind == 1:  # table
                section.byte()
                skip_limits(section)
            elif kind == 2:  # memory
                skip_limits(section)
            elif kind == 3:  # global
                section.byte()
                section.byte()
            elif kind == 4:  # tag
                section.uleb()
                section.uleb()
            else:
                raise ValueError(f"unknown WebAssembly import kind: {kind}")

        if section.offset != len(section.data):
            raise ValueError("trailing bytes in WebAssembly import section")

    return imports


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("module", type=Path)
    args = parser.parse_args()

    try:
        module = args.module.read_bytes()
        imports = imports_from(module)
    except (OSError, UnicodeDecodeError, ValueError) as error:
        print(f"WASM import verification failed: {error}", file=sys.stderr)
        return 1

    forbidden = [f"{namespace}.{name}" for namespace, name in imports if name in FORBIDDEN]
    if forbidden:
        print(
            f"WASM import verification failed: C-runtime host imports: {forbidden}",
            file=sys.stderr,
        )
        return 1

    payload_hits = [payload for payload in FORBIDDEN_PAYLOADS if payload in module]
    if payload_hits:
        rendered_payloads = [payload.decode("ascii") for payload in payload_hits]
        print(
            f"WASM import verification failed: native diagnostics present: {rendered_payloads}",
            file=sys.stderr,
        )
        return 1

    rendered = ", ".join(f"{namespace}.{name}" for namespace, name in imports) or "none"
    print(
        "WASM C-runtime imports passed: "
        f"forbidden=0, native_diagnostics=0, imports=[{rendered}]"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
