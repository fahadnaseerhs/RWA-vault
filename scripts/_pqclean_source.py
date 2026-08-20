"""Shared PQClean source-plan and pinned-Git helpers."""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
from pathlib import Path, PurePosixPath
import re
import subprocess
import tempfile

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
NATIVE_ROOT = REPOSITORY_ROOT / "packages" / "pq-core" / "native"
SOURCE_PLAN_PATH = NATIVE_ROOT / "pqclean-source-plan.txt"
VENDOR_ROOT = NATIVE_ROOT / "vendor" / "pqclean"
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")


@dataclass(frozen=True)
class SourceGroup:
    library: str
    directory: str
    compiled_files: tuple[str, ...]
    vendor_tree: bool
    vendor_files: tuple[str, ...]


@dataclass(frozen=True)
class SourcePlan:
    upstream_url: str
    commit: str
    groups: tuple[SourceGroup, ...]

    @property
    def cache_root(self) -> Path:
        return Path(tempfile.gettempdir()) / f"rwa-vault-pqclean-{self.commit}.git"


@dataclass(frozen=True)
class UpstreamEntry:
    path: str
    git_object: str
    sha256: str


def _safe_relative_path(value: str, context: str) -> str:
    path = PurePosixPath(value)
    if not value or path.is_absolute() or ".." in path.parts or "\\" in value:
        raise ValueError(f"unsafe {context}: {value}")
    return value


def _csv(value: str, context: str) -> tuple[str, ...]:
    values = tuple(item for item in value.split(",") if item)
    if not values or len(values) != len(set(values)):
        raise ValueError(f"invalid or duplicate {context}: {value}")
    return values


def load_source_plan() -> SourcePlan:
    upstream_url: str | None = None
    commit: str | None = None
    groups: list[SourceGroup] = []

    for number, raw_line in enumerate(
        SOURCE_PLAN_PATH.read_text(encoding="utf-8").splitlines(), start=1
    ):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split("|")
        kind = fields[0]
        if kind == "upstream" and len(fields) == 2 and upstream_url is None:
            upstream_url = fields[1]
            continue
        if kind == "commit" and len(fields) == 2 and commit is None:
            commit = fields[1]
            continue
        # group|static-library|upstream-directory|compiled-c-files|vendored-selection
        if kind != "group" or len(fields) != 5:
            raise ValueError(f"invalid source-plan line {number}: {raw_line}")

        _, library, directory, compiled_csv, selection = fields
        _safe_relative_path(directory, "source directory")
        compiled_files = _csv(compiled_csv, "compiled file list")
        for filename in compiled_files:
            _safe_relative_path(filename, "compiled filename")
            if "/" in filename or not filename.endswith(".c"):
                raise ValueError(f"compiled source must be a local .c file: {filename}")

        if selection == "tree":
            vendor_tree = True
            vendor_files: tuple[str, ...] = ()
        elif selection.startswith("files:"):
            vendor_tree = False
            vendor_files = _csv(selection.removeprefix("files:"), "vendor file list")
            for filename in vendor_files:
                _safe_relative_path(filename, "vendored filename")
                if "/" in filename:
                    raise ValueError(f"vendored support file must be local: {filename}")
        else:
            raise ValueError(f"invalid vendored selection on line {number}: {selection}")

        groups.append(
            SourceGroup(library, directory, compiled_files, vendor_tree, vendor_files)
        )

    if upstream_url is None or commit is None or not groups:
        raise ValueError("source plan must define one upstream, one commit, and groups")
    if not COMMIT_PATTERN.fullmatch(commit):
        raise ValueError(f"source-plan commit is not a full lowercase SHA-1: {commit}")
    if len(groups) != 6:
        raise ValueError(f"source plan must contain exactly six build groups, got {len(groups)}")
    if len({group.library for group in groups}) != len(groups):
        raise ValueError("source plan contains duplicate static-library names")
    if len({group.directory for group in groups}) != len(groups):
        raise ValueError("source plan contains duplicate source directories")

    return SourcePlan(upstream_url, commit, tuple(groups))


# Git content filters must never run against the vendored selection. `git archive`
# honours core.autocrlf, so on a developer machine with autocrlf=true it emits
# CRLF-converted bytes that no longer match the upstream blob — vendoring would
# then depend on the operator's Git config and differ between Windows and Linux.
# These overrides pin every invocation to raw object bytes.
GIT_RAW_BYTES = ("-c", "core.autocrlf=false", "-c", "core.eol=lf")


def run_git(
    plan: SourcePlan, *args: str, capture: bool = False
) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        ("git", *GIT_RAW_BYTES, "--git-dir", str(plan.cache_root), *args),
        check=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


def ensure_cached_commit(plan: SourcePlan) -> bool:
    """Return True only when the immutable commit needed a network fetch."""
    if not plan.cache_root.exists():
        plan.cache_root.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(("git", "init", "--bare", str(plan.cache_root)), check=True)
        run_git(plan, "remote", "add", "origin", plan.upstream_url)

    present = subprocess.run(
        (
            "git",
            "--git-dir",
            str(plan.cache_root),
            "cat-file",
            "-e",
            f"{plan.commit}^{{commit}}",
        ),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    ).returncode == 0
    if not present:
        run_git(plan, "fetch", "--depth=1", "origin", plan.commit)

    resolved = run_git(
        plan, "rev-parse", f"{plan.commit}^{{commit}}", capture=True
    ).stdout.decode("ascii").strip()
    if resolved != plan.commit:
        raise RuntimeError(
            f"PQClean commit mismatch: expected {plan.commit}, got {resolved}"
        )
    return not present


def git_object(plan: SourcePlan, path: str) -> str:
    return run_git(
        plan, "rev-parse", f"{plan.commit}:{path}", capture=True
    ).stdout.decode("ascii").strip()


def commit_tree(plan: SourcePlan) -> str:
    return run_git(
        plan, "rev-parse", f"{plan.commit}^{{tree}}", capture=True
    ).stdout.decode("ascii").strip()


def selected_paths(plan: SourcePlan) -> tuple[str, ...]:
    selected: list[str] = []
    for group in plan.groups:
        if group.vendor_tree:
            output = run_git(
                plan,
                "ls-tree",
                "-r",
                "--name-only",
                plan.commit,
                "--",
                group.directory,
                capture=True,
            ).stdout.decode("utf-8")
            paths = tuple(line for line in output.splitlines() if line)
            if not paths:
                raise RuntimeError(f"empty upstream source directory: {group.directory}")
            selected.extend(paths)
        else:
            selected.extend(f"{group.directory}/{name}" for name in group.vendor_files)

    if len(selected) != len(set(selected)):
        raise RuntimeError("source plan selects a vendored path more than once")
    return tuple(sorted(selected))


def upstream_entries(plan: SourcePlan) -> tuple[UpstreamEntry, ...]:
    entries: list[UpstreamEntry] = []
    for path in selected_paths(plan):
        content = run_git(
            plan, "show", f"{plan.commit}:{path}", capture=True
        ).stdout
        entries.append(
            UpstreamEntry(path, git_object(plan, path), hashlib.sha256(content).hexdigest())
        )
    return tuple(entries)


def selection_digest(entries: tuple[UpstreamEntry, ...]) -> str:
    content = "".join(
        f"{entry.git_object}  {entry.path}\n" for entry in sorted(entries, key=lambda item: item.path)
    ).encode("utf-8")
    return hashlib.sha256(content).hexdigest()
