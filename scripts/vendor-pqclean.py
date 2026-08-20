#!/usr/bin/env python3
"""Vendor the reviewed PQClean subset at one immutable commit."""

from __future__ import annotations

import hashlib
from pathlib import Path, PurePosixPath
import shutil
import tarfile
import tempfile

from _pqclean_source import (
    SourcePlan,
    UpstreamEntry,
    VENDOR_ROOT,
    commit_tree,
    ensure_cached_commit,
    git_object,
    load_source_plan,
    run_git,
    selected_paths,
    selection_digest,
    upstream_entries,
)


def archive_paths(plan: SourcePlan) -> tuple[str, ...]:
    paths: list[str] = []
    for group in plan.groups:
        if group.vendor_tree:
            paths.append(group.directory)
        else:
            paths.extend(f"{group.directory}/{name}" for name in group.vendor_files)
    return tuple(paths)


def extract_reviewed_tree(plan: SourcePlan, staging: Path) -> None:
    archive_path = staging.parent / "pqclean-reviewed.tar"
    run_git(
        plan,
        "archive",
        "--format=tar",
        f"--output={archive_path}",
        plan.commit,
        "--",
        *archive_paths(plan),
    )

    staging_root = staging.resolve()
    with tarfile.open(archive_path, mode="r:") as archive:
        for member in archive.getmembers():
            if member.isdir():
                continue
            if not member.isfile():
                raise RuntimeError(f"unsupported archive entry: {member.name}")

            relative = PurePosixPath(member.name)
            if relative.is_absolute() or ".." in relative.parts:
                raise RuntimeError(f"unsafe archive path: {member.name}")

            destination = (staging / Path(*relative.parts)).resolve()
            if staging_root not in destination.parents:
                raise RuntimeError(f"archive path escapes staging root: {member.name}")

            source = archive.extractfile(member)
            if source is None:
                raise RuntimeError(f"cannot read archive entry: {member.name}")
            destination.parent.mkdir(parents=True, exist_ok=True)
            with destination.open("wb") as output:
                shutil.copyfileobj(source, output)

    archive_path.unlink()


def git_blob_id(content: bytes) -> str:
    framed = f"blob {len(content)}\0".encode("ascii") + content
    return hashlib.sha1(framed).hexdigest()


def validate_staging(
    staging: Path, expected_entries: tuple[UpstreamEntry, ...]
) -> None:
    actual_paths = {
        path.relative_to(staging).as_posix()
        for path in staging.rglob("*")
        if path.is_file()
    }
    expected_paths = {entry.path for entry in expected_entries}
    if actual_paths != expected_paths:
        missing = sorted(expected_paths - actual_paths)
        extra = sorted(actual_paths - expected_paths)
        raise RuntimeError(f"archive selection mismatch: missing={missing}, extra={extra}")

    for entry in expected_entries:
        content = (staging / Path(entry.path)).read_bytes()
        if git_blob_id(content) != entry.git_object:
            raise RuntimeError(f"archive content differs from pinned Git object: {entry.path}")


def provenance(plan: SourcePlan, entries: tuple[UpstreamEntry, ...]) -> bytes:
    roots = "\n".join(
        f"- `{group.directory}/` at Git object `{git_object(plan, group.directory)}` "
        f"({('complete tree' if group.vendor_tree else 'selected files only')})"
        for group in plan.groups
    )
    checksums = "\n".join(
        f"{entry.sha256}  {entry.git_object}  {entry.path}" for entry in entries
    )
    text = f"""# PQClean Provenance

- Upstream: `{plan.upstream_url}`
- Commit: `{plan.commit}`
- Commit tree: `{commit_tree(plan)}`
- Selection digest: `{selection_digest(entries)}`
- Selection: five portable `clean` scheme trees plus four named common support files

## Vendored Source Roots

<!-- roots:start -->
{roots}
<!-- roots:end -->

## Upstream-Anchored Manifest

Each row records the SHA-256, Git blob object ID, and path derived directly from
the pinned commit. `PROVENANCE.md` is generated metadata and is not part of the
upstream selection.

<!-- manifest:start -->
```text
{checksums}
```
<!-- manifest:end -->
"""
    return text.encode("utf-8")


def sync(
    staging: Path, plan: SourcePlan, entries: tuple[UpstreamEntry, ...]
) -> tuple[int, int, int]:
    desired = {
        path.relative_to(staging): path.read_bytes()
        for path in staging.rglob("*")
        if path.is_file()
    }
    desired[Path("PROVENANCE.md")] = provenance(plan, entries)

    existing = (
        {
            path.relative_to(VENDOR_ROOT): path
            for path in VENDOR_ROOT.rglob("*")
            if path.is_file()
        }
        if VENDOR_ROOT.exists()
        else {}
    )

    removed = 0
    for relative, path in existing.items():
        if relative not in desired:
            path.unlink()
            removed += 1

    written = 0
    unchanged = 0
    for relative, content in desired.items():
        destination = VENDOR_ROOT / relative
        if destination.is_file() and destination.read_bytes() == content:
            unchanged += 1
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content)
        written += 1

    if VENDOR_ROOT.exists():
        for directory in sorted(
            (item for item in VENDOR_ROOT.rglob("*") if item.is_dir()),
            key=lambda item: len(item.parts),
            reverse=True,
        ):
            try:
                directory.rmdir()
            except OSError:
                pass

    return written, unchanged, removed


def main() -> None:
    plan = load_source_plan()
    fetched = ensure_cached_commit(plan)
    entries = upstream_entries(plan)
    if tuple(entry.path for entry in entries) != selected_paths(plan):
        raise RuntimeError("upstream manifest path order is inconsistent")

    with tempfile.TemporaryDirectory(prefix="rwa-vault-pqclean-stage-") as directory:
        staging = Path(directory) / "pqclean"
        staging.mkdir()
        extract_reviewed_tree(plan, staging)
        validate_staging(staging, entries)
        written, unchanged, removed = sync(staging, plan, entries)

    network = "fetched pinned commit" if fetched else "used verified local commit cache"
    print(
        f"PQClean {plan.commit}: {network}; "
        f"written={written}, unchanged={unchanged}, removed={removed}"
    )


if __name__ == "__main__":
    main()
