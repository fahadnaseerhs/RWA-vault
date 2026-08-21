#!/usr/bin/env python3
"""Audit the exact freestanding C commands resolved by cc in build.rs."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import os
from pathlib import Path
import re
import subprocess
import sys

from _pqclean_source import NATIVE_ROOT, load_source_plan

REQUIRED_FLAGS = {
    "--target=wasm32-unknown-unknown",
    "-nostdlibinc",
    "-ffreestanding",
    "-std=c99",
}
FORBIDDEN_COMPILE_FLAGS = {"-nostdlib"}
HOST_PATH = re.compile(
    r"(?:/usr/(?:local/)?include|"
    r"[A-Za-z]:[\\/].*?(?:Microsoft Visual Studio|Windows Kits|msys64|mingw32|mingw64|ucrt64|clang64)|"
    r"/(?:msys64|mingw32|mingw64|ucrt64|clang64)/|"
    r"/mnt/[A-Za-z]/.*?(?:msys64|mingw32|mingw64|Windows Kits|Microsoft Visual Studio))",
    re.IGNORECASE,
)
INCLUDE_TRACE = re.compile(r"^\.+\s+(.+?)\s*$")


@dataclass
class BuildGroup:
    name: str
    compiler: str
    arguments: list[str]
    sources: list[Path]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--manifest",
        type=Path,
        help="build.rs-generated wasm-c-audit.txt (auto-discovered by default)",
    )
    return parser.parse_args()


def discover_manifest(requested: Path | None) -> Path:
    if requested is not None:
        manifest = requested.resolve()
        if not manifest.is_file():
            raise ValueError(f"WASM audit manifest does not exist: {manifest}")
        return manifest

    target_dir = Path(os.environ.get("CARGO_TARGET_DIR", NATIVE_ROOT / "target"))
    if not target_dir.is_absolute():
        target_dir = NATIVE_ROOT / target_dir
    candidates = list(
        target_dir.glob(
            "wasm32-unknown-unknown/*/build/rwa-vault-pq-core-*/out/wasm-c-audit.txt"
        )
    )
    if not candidates:
        raise ValueError(
            "no build.rs WASM audit manifest found; run "
            "`cargo build --target wasm32-unknown-unknown` first"
        )
    return max(candidates, key=lambda path: path.stat().st_mtime).resolve()


def load_manifest(path: Path) -> list[BuildGroup]:
    groups: list[BuildGroup] = []
    current: dict[str, object] | None = None

    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        try:
            kind, value = raw_line.split("\t", 1)
        except ValueError as error:
            raise ValueError(f"{path}:{line_number}: malformed audit record") from error
        if not value:
            raise ValueError(f"{path}:{line_number}: empty {kind} value")

        if kind == "group":
            if current is not None:
                raise ValueError(f"{path}:{line_number}: nested group")
            current = {"name": value, "compiler": None, "arguments": [], "sources": []}
        elif current is None:
            raise ValueError(f"{path}:{line_number}: {kind} outside a group")
        elif kind == "compiler":
            if current["compiler"] is not None:
                raise ValueError(f"{path}:{line_number}: duplicate compiler")
            current["compiler"] = value
        elif kind == "arg":
            current["arguments"].append(value)  # type: ignore[union-attr]
        elif kind == "source":
            current["sources"].append(Path(value).resolve())  # type: ignore[union-attr]
        elif kind == "end":
            if value != current["name"]:
                raise ValueError(f"{path}:{line_number}: mismatched group end")
            if current["compiler"] is None or not current["sources"]:
                raise ValueError(f"{path}:{line_number}: incomplete group")
            groups.append(
                BuildGroup(
                    name=str(current["name"]),
                    compiler=str(current["compiler"]),
                    arguments=list(current["arguments"]),  # type: ignore[arg-type]
                    sources=list(current["sources"]),  # type: ignore[arg-type]
                )
            )
            current = None
        else:
            raise ValueError(f"{path}:{line_number}: unknown record type {kind}")

    if current is not None:
        raise ValueError(f"{path}: unterminated group {current['name']}")
    if not groups:
        raise ValueError(f"{path}: no build groups")
    return groups


def expected_sources() -> set[Path]:
    plan = load_source_plan()
    vendor_root = NATIVE_ROOT / "vendor" / "pqclean"
    return {
        (vendor_root / group.directory / filename).resolve()
        for group in plan.groups
        for filename in group.compiled_files
    }


def include_roots(arguments: list[str]) -> list[Path]:
    roots: list[Path] = []
    index = 0
    while index < len(arguments):
        argument = arguments[index]
        if argument == "-I":
            index += 1
            if index >= len(arguments):
                raise ValueError("compiler arguments end with bare -I")
            roots.append(Path(arguments[index]).resolve())
        elif argument.startswith("-I") and len(argument) > 2:
            roots.append(Path(argument[2:]).resolve())
        index += 1
    return roots


def compiler_resource_include(group: BuildGroup) -> Path:
    target_flags = [
        argument for argument in group.arguments if argument.startswith("--target=")
    ]
    result = subprocess.run(
        [group.compiler, *target_flags, "-print-resource-dir"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        text=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        diagnostic = result.stderr.strip()
        raise ValueError(f"cannot discover Clang resource headers: {diagnostic}")
    resource_include = (Path(result.stdout.strip()) / "include").resolve()
    if not resource_include.is_dir():
        raise ValueError(f"Clang resource include directory is missing: {resource_include}")
    return resource_include


def is_within(path: Path, roots: list[Path]) -> bool:
    for root in roots:
        try:
            path.relative_to(root)
            return True
        except ValueError:
            pass
    return False


def assert_remains_active(group: BuildGroup) -> None:
    probe = "#include <assert.h>\nvoid probe(void) { assert(0); }\n"
    result = subprocess.run(
        [
            group.compiler,
            *group.arguments,
            "-DNDEBUG",
            "-E",
            "-P",
            "-x",
            "c",
            "-",
        ],
        input=probe,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        text=True,
    )
    if result.returncode != 0:
        raise ValueError(f"assert profile probe failed: {result.stderr.strip()}")
    if "__builtin_trap" not in result.stdout:
        raise ValueError("assert becomes inactive when NDEBUG is defined")


def main() -> int:
    try:
        manifest_path = discover_manifest(parse_args().manifest)
        groups = load_manifest(manifest_path)
    except ValueError as error:
        print(f"PQClean WASM preprocessor verification failed: {error}", file=sys.stderr)
        return 1

    failures: list[str] = []
    actual_sources = {source for group in groups for source in group.sources}
    expected = expected_sources()
    if actual_sources != expected:
        missing = sorted(str(path) for path in expected - actual_sources)
        extra = sorted(str(path) for path in actual_sources - expected)
        failures.append(f"build source-set mismatch: missing={missing}, extra={extra}")

    host_hits: list[str] = []
    inspected = 0
    for group in groups:
        missing_flags = REQUIRED_FLAGS - set(group.arguments)
        if missing_flags:
            failures.append(f"{group.name}: build omitted required flags: {sorted(missing_flags)}")
        forbidden_flags = FORBIDDEN_COMPILE_FLAGS & set(group.arguments)
        if forbidden_flags:
            failures.append(
                f"{group.name}: link-only flags passed while compiling: {sorted(forbidden_flags)}"
            )
        wrong_targets = [
            argument
            for argument in group.arguments
            if argument.startswith("--target=")
            and argument != "--target=wasm32-unknown-unknown"
        ]
        if wrong_targets:
            failures.append(f"{group.name}: conflicting targets: {wrong_targets}")

        try:
            includes = include_roots(group.arguments)
            allowed_headers = [*includes, compiler_resource_include(group)]
        except ValueError as error:
            failures.append(f"{group.name}: {error}")
            continue
        if not includes:
            failures.append(f"{group.name}: build emitted no include directories")
            continue

        for source in group.sources:
            command = [group.compiler, *group.arguments, "-E", "-H", str(source)]
            result = subprocess.run(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            inspected += 1
            diagnostic = result.stderr.decode("utf-8", errors="replace")
            output = result.stdout.decode("utf-8", errors="replace")
            if result.returncode != 0:
                failures.append(f"{source}: preprocess failed: {diagnostic.strip()}")
                continue

            combined = output + diagnostic
            for match in HOST_PATH.finditer(combined):
                host_hits.append(f"{source}: {match.group(0)}")

            for line in diagnostic.splitlines():
                match = INCLUDE_TRACE.match(line)
                if match is None:
                    continue
                header = Path(match.group(1)).resolve()
                if not is_within(header, allowed_headers):
                    host_hits.append(f"{source}: header outside build include roots: {header}")

    try:
        assert_remains_active(groups[0])
    except ValueError as error:
        failures.append(str(error))

    if failures or host_hits:
        print("PQClean WASM preprocessor verification failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        for hit in host_hits:
            print(f"- host-header reference: {hit}", file=sys.stderr)
        return 1

    print(
        "PQClean WASM preprocessing passed: "
        f"manifest={manifest_path}, groups={len(groups)}, files={inspected}, "
        "host_header_hits=0, ndebug_assert=trap"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
