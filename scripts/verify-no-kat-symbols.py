#!/usr/bin/env python3
"""Prove the deterministic KAT hooks are absent from a default build (S2-15).

ADR 0007's rule is not "the deterministic entry points are disabled in
production" — it is that they *do not exist* there. `#[cfg(feature = "kat")]`
means a default build never compiles them, and `compile_error!` means an
optimised build cannot enable them. Both are source-level claims. This script
is the artefact-level check that closes the loop: it reads the bytes that were
actually produced and fails if any hook name appears in compiled output.

What "compiled output" means, precisely
--------------------------------------

A linked artefact — `.dll`, `.so`, `.dylib`, `.wasm`, `.exe` — is scanned whole.
Nothing about a cfg-stripped item should survive into one, so a single byte
match is a failure.

An `.rlib` is not a linked artefact. It is an `ar` archive holding the compiled
object members, the archive symbol index, and `lib.rmeta` — rustc's crate
metadata. The metadata carries rustc's interned identifier table, which is
populated by the *parser*, before `#[cfg]` stripping removes the items. So the
strings `keygen_from_seed`, `sign_deterministic`, `encapsulate_with_m` do appear
in `lib.rmeta` of a default build, next to `fail_next_draw` (a `#[cfg(test)]`
function) and the string `wasm32` (a cfg value) — as names, with no item, no MIR
and no code behind them.

`lib.rmeta` is therefore excluded from the scan, and every exclusion is printed
rather than applied silently: a check that quietly skips the one place a hit
occurs is not evidence. What is *not* excluded is the part that matters — every
object member and the archive symbol index. A `pub fn keygen_from_seed` compiled
into the crate would appear there under a mangled symbol that still contains the
identifier verbatim, in both rustc's legacy and v0 mangling schemes.

The complementary source-level proof is in `native/src/lib.rs`: a `compile_fail`
doctest that names each hook and must not resolve without the `kat` feature.

This check is only worth running if it can fail, so `--self-test` runs the same
matcher over a buffer that does contain the names and requires it to find them.
CI runs the self-test and the scan together; a scanner that silently matched
nothing would pass the scan alone.

Usage:
    verify-no-kat-symbols.py <file-or-directory> [...]
    verify-no-kat-symbols.py --self-test
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

# The three seed-taking entry points named by S2-15, plus the entropy-override
# scope that makes them work. Any one of these in compiled output means a
# non-OS entropy path reached the artefact.
FORBIDDEN_NAMES = (
    "keygen_from_seed",
    "sign_deterministic",
    "encapsulate_with_m",
    "with_kat_entropy",
)

LINKED_SUFFIXES = (".dll", ".so", ".dylib", ".wasm", ".exe")
ARCHIVE_SUFFIXES = (".rlib", ".a")

# rustc's crate metadata. See the module docstring for why it is excluded and
# why excluding it does not weaken the check.
METADATA_MEMBERS = ("lib.rmeta", "rust.metadata.bin")

CRATE_STEMS = ("rwa_vault_pq_core", "librwa_vault_pq_core")

AR_MAGIC = b"!<arch>\n"


def is_artefact(path: Path) -> bool:
    if path.suffix not in LINKED_SUFFIXES + ARCHIVE_SUFFIXES:
        return False
    return any(path.name.startswith(stem) for stem in CRATE_STEMS)


def collect(targets: list[Path]) -> list[Path]:
    found: list[Path] = []
    for target in targets:
        if target.is_dir():
            # Only the directory itself, not `deps/` — that holds binaries from
            # every feature set ever built in this tree, including the
            # acknowledged-override `kat` conformance run. Those are test
            # reports, not release artefacts (ADR 0008).
            found.extend(sorted(child for child in target.iterdir() if is_artefact(child)))
        elif target.is_file():
            found.append(target)
        else:
            raise SystemExit(f"error: no such file or directory: {target}")
    return found


def scan(data: bytes) -> list[str]:
    """Return every forbidden name present in `data`."""
    return [name for name in FORBIDDEN_NAMES if name.encode("ascii") in data]


def ar_members(data: bytes):
    """Yield `(member_name, member_bytes)` for a `ar` archive."""
    if not data.startswith(AR_MAGIC):
        raise ValueError("not an ar archive")
    offset = len(AR_MAGIC)
    while offset + 60 <= len(data):
        header = data[offset : offset + 60]
        if header[58:60] != b"`\n":
            raise ValueError(f"malformed archive header at offset {offset}")
        name = header[0:16].decode("ascii", "replace").strip().rstrip("/")
        size = int(header[48:58].decode("ascii").strip())
        body = data[offset + 60 : offset + 60 + size]
        yield name, body
        offset += 60 + size + (size % 2)


def check_linked(path: Path) -> tuple[bool, list[str]]:
    hits = scan(path.read_bytes())
    return not hits, hits


def check_archive(path: Path) -> tuple[bool, list[str], list[str]]:
    """Scan every archive member except rustc metadata.

    Returns `(ok, hits, notes)`. `notes` records excluded members that did
    contain a name, so the exclusion is always visible in the output.
    """
    hits: list[str] = []
    notes: list[str] = []
    members = 0
    for name, body in ar_members(path.read_bytes()):
        found = scan(body)
        if name in METADATA_MEMBERS:
            if found:
                notes.append(
                    f"excluded rustc metadata member {name!r} names "
                    f"{', '.join(found)} (interned identifiers, no item)"
                )
            continue
        members += 1
        for hit in found:
            hits.append(f"{hit} (in member {name!r})")
    if members == 0:
        hits.append("archive contained no scannable members")
    return not hits, hits, notes


def self_test() -> int:
    positive = b"\x00\x01padding" + b"".join(name.encode("ascii") for name in FORBIDDEN_NAMES)
    found = scan(positive)
    if sorted(found) != sorted(FORBIDDEN_NAMES):
        print(
            f"self-test failed: matcher found {found}, expected {list(FORBIDDEN_NAMES)}",
            file=sys.stderr,
        )
        return 1
    if scan(b"a build with no deterministic hooks in it at all"):
        print("self-test failed: matcher reported a hit on clean input", file=sys.stderr)
        return 1

    # A mangled Rust symbol still carries the identifier verbatim. Both mangling
    # schemes are checked so the scan cannot be defeated by `-C symbol-mangling`.
    mangled = [
        b"_ZN18rwa_vault_pq_core3kat16keygen_from_seed17h0123456789abcdefE",
        b"_RNvNtCsA1b2C3d4_17rwa_vault_pq_core3kat18sign_deterministic",
    ]
    for symbol in mangled:
        if not scan(symbol):
            print(f"self-test failed: mangled symbol {symbol!r} not detected", file=sys.stderr)
            return 1

    print(f"self-test passed: the matcher detects all {len(FORBIDDEN_NAMES)} names, mangled or not")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "targets",
        nargs="*",
        type=Path,
        help="build artefacts, or directories holding them",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="verify the matcher itself, then exit",
    )
    arguments = parser.parse_args()

    if arguments.self_test:
        return self_test()

    if not arguments.targets:
        parser.error("give at least one artefact or directory, or pass --self-test")

    artefacts = collect(arguments.targets)
    if not artefacts:
        # A scan of nothing must never report success. This is the same
        # zero-case rule the conformance report applies in S4-17.
        print(
            "error: no pq-core build artefacts found — did the release build run?",
            file=sys.stderr,
        )
        return 1

    failed = False
    for artefact in artefacts:
        size = artefact.stat().st_size
        if artefact.suffix in ARCHIVE_SUFFIXES:
            ok, hits, notes = check_archive(artefact)
            for note in notes:
                print(f"note {artefact.name}: {note}")
        else:
            ok, hits = check_linked(artefact)
        if ok:
            print(f"ok   {artefact} ({size} bytes): no deterministic KAT hook in compiled output")
        else:
            failed = True
            print(f"FAIL {artefact} ({size} bytes): {'; '.join(hits)}", file=sys.stderr)

    if failed:
        print(
            "\nerror: a default build artefact carries a deterministic KAT entry "
            "point. ADR 0007 requires these to be absent, not merely unreachable.",
            file=sys.stderr,
        )
        return 1

    print(f"\n{len(artefacts)} artefact(s) scanned; no deterministic KAT hooks present")
    return 0


if __name__ == "__main__":
    sys.exit(main())
