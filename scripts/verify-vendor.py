#!/usr/bin/env python3
"""Verify vendored PQClean bytes against objects in the pinned upstream commit."""

from __future__ import annotations

import hashlib
from pathlib import Path
import re
import sys

from _pqclean_source import (
    SourcePlan,
    UpstreamEntry,
    VENDOR_ROOT,
    commit_tree,
    ensure_cached_commit,
    git_object,
    load_source_plan,
    selection_digest,
    upstream_entries,
)

PROVENANCE_PATH = VENDOR_ROOT / "PROVENANCE.md"
MANIFEST_LINE = re.compile(r"^([0-9a-f]{64})  ([0-9a-f]{40})  (.+)$")
ROOT_LINE = re.compile(
    r"^- `([^`]+)/` at Git object `([0-9a-f]{40})` "
    r"\((complete tree|selected files only)\)$"
)


def sha256(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def git_blob_id(content: bytes) -> str:
    framed = f"blob {len(content)}\0".encode("ascii") + content
    return hashlib.sha1(framed).hexdigest()


def metadata(text: str, label: str) -> str:
    match = re.search(rf"^- {re.escape(label)}: `([^`]+)`$", text, re.MULTILINE)
    if match is None:
        raise ValueError(f"PROVENANCE.md is missing {label.lower()}")
    return match.group(1)


def marked_body(text: str, marker: str) -> str:
    try:
        return text.split(f"<!-- {marker}:start -->", 1)[1].split(
            f"<!-- {marker}:end -->", 1
        )[0]
    except IndexError as error:
        raise ValueError(f"PROVENANCE.md is missing {marker} markers") from error


def parse_manifest(text: str) -> dict[str, tuple[str, str]]:
    entries: dict[str, tuple[str, str]] = {}
    for line in marked_body(text, "manifest").splitlines():
        match = MANIFEST_LINE.fullmatch(line)
        if match is None:
            continue
        digest, object_id, relative = match.groups()
        path = Path(relative)
        if path.is_absolute() or ".." in path.parts or "\\" in relative:
            raise ValueError(f"unsafe manifest path: {relative}")
        if relative in entries:
            raise ValueError(f"duplicate manifest path: {relative}")
        entries[relative] = (digest, object_id)

    if not entries:
        raise ValueError("PROVENANCE.md contains no manifest entries")
    return entries


def parse_roots(text: str) -> dict[str, tuple[str, str]]:
    roots: dict[str, tuple[str, str]] = {}
    for line in marked_body(text, "roots").splitlines():
        match = ROOT_LINE.fullmatch(line)
        if match is None:
            continue
        directory, object_id, selection = match.groups()
        if directory in roots:
            raise ValueError(f"duplicate provenance source root: {directory}")
        roots[directory] = (object_id, selection)
    if not roots:
        raise ValueError("PROVENANCE.md contains no source roots")
    return roots


def expected_roots(plan: SourcePlan) -> dict[str, tuple[str, str]]:
    return {
        group.directory: (
            git_object(plan, group.directory),
            "complete tree" if group.vendor_tree else "selected files only",
        )
        for group in plan.groups
    }


def verify() -> list[str]:
    errors: list[str] = []
    if not PROVENANCE_PATH.is_file():
        return [f"missing provenance file: {PROVENANCE_PATH}"]

    try:
        plan = load_source_plan()
        ensure_cached_commit(plan)
        upstream = upstream_entries(plan)
        expected_by_path = {entry.path: entry for entry in upstream}
        text = PROVENANCE_PATH.read_text(encoding="utf-8")
        manifest = parse_manifest(text)
        roots = parse_roots(text)
    except (OSError, RuntimeError, ValueError) as error:
        return [str(error)]

    expected_metadata = {
        "Upstream": plan.upstream_url,
        "Commit": plan.commit,
        "Commit tree": commit_tree(plan),
        "Selection digest": selection_digest(upstream),
    }
    for label, expected in expected_metadata.items():
        try:
            actual = metadata(text, label)
        except ValueError as error:
            errors.append(str(error))
            continue
        if actual != expected:
            errors.append(
                f"provenance {label.lower()} does not match pinned upstream: "
                f"expected {expected}, got {actual}"
            )

    anchored_roots = expected_roots(plan)
    if roots != anchored_roots:
        errors.append("provenance source roots do not match the shared source plan")

    actual_files = {
        path.relative_to(VENDOR_ROOT).as_posix()
        for path in VENDOR_ROOT.rglob("*")
        if path.is_file() and path != PROVENANCE_PATH
    }
    expected_files = set(expected_by_path)
    manifest_files = set(manifest)

    for relative in sorted(expected_files - actual_files):
        errors.append(f"missing vendored file: {relative}")
    for relative in sorted(actual_files - expected_files):
        errors.append(f"unapproved vendored file: {relative}")
    for relative in sorted(expected_files - manifest_files):
        errors.append(f"missing provenance entry: {relative}")
    for relative in sorted(manifest_files - expected_files):
        errors.append(f"provenance contains path outside pinned selection: {relative}")

    for relative in sorted(expected_files & manifest_files):
        expected: UpstreamEntry = expected_by_path[relative]
        manifest_sha256, manifest_object = manifest[relative]
        if manifest_sha256 != expected.sha256:
            errors.append(f"manifest SHA-256 differs from pinned upstream: {relative}")
        if manifest_object != expected.git_object:
            errors.append(f"manifest Git object differs from pinned upstream: {relative}")

    for relative in sorted(expected_files & actual_files):
        expected = expected_by_path[relative]
        content = (VENDOR_ROOT / Path(relative)).read_bytes()
        if sha256(content) != expected.sha256:
            errors.append(f"vendored bytes differ from pinned upstream: {relative}")
        if git_blob_id(content) != expected.git_object:
            errors.append(f"vendored Git object differs from pinned upstream: {relative}")

    return errors


def main() -> int:
    errors = verify()
    if errors:
        print("PQClean vendor verification failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    plan = load_source_plan()
    print(f"PQClean vendor verification passed against upstream commit {plan.commit}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
