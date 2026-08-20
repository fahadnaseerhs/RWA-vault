use std::collections::HashSet;
use std::path::{Component, Path, PathBuf};

const VENDOR_ROOT: &str = "vendor/pqclean";
const SOURCE_PLAN_PATH: &str = "pqclean-source-plan.txt";
const SOURCE_PLAN: &str = include_str!("pqclean-source-plan.txt");

struct SourceGroup<'a> {
    library: &'a str,
    directory: &'a str,
    files: Vec<&'a str>,
}

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed={SOURCE_PLAN_PATH}");

    // The vendored sources include <string.h>/<stdint.h>. wasm32-unknown-unknown has
    // no C sysroot to resolve them against, so `cc` cannot build them for the browser
    // target no matter what flags it is given. Fail here, naming the open decision,
    // rather than deep inside a vendored translation unit.
    let target_arch = std::env::var("CARGO_CFG_TARGET_ARCH").unwrap_or_default();
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    if target_arch == "wasm32" && target_os == "unknown" {
        panic!(
            "wasm32-unknown-unknown cannot compile the vendored PQClean C: the target \
             has no C sysroot. The browser build target is unresolved; see \
             docs/adr/0004-wasm-build-target.md"
        );
    }

    let vendor_root = PathBuf::from(VENDOR_ROOT);
    if !vendor_root.is_dir() {
        panic!(
            "vendored PQClean sources are missing; run scripts/vendor-pqclean.py from the repository root"
        );
    }

    for group in parse_source_plan() {
        compile_group(&vendor_root, &group);
    }

    // `common/randombytes.c` is deliberately not in the shared source plan. The
    // Rust FFI layer owns the PQCLEAN_randombytes symbol so production has one
    // target-specific entropy path through `getrandom` (ADR 0007).
}

fn parse_source_plan() -> Vec<SourceGroup<'static>> {
    let mut upstream_count = 0;
    let mut commit_count = 0;
    let mut groups = Vec::new();
    let mut libraries = HashSet::new();
    let mut directories = HashSet::new();

    for (index, raw_line) in SOURCE_PLAN.lines().enumerate() {
        let line = raw_line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        let fields: Vec<&str> = line.split('|').collect();
        match fields.as_slice() {
            ["upstream", value] if !value.is_empty() => upstream_count += 1,
            ["commit", value]
                if value.len() == 40 && value.bytes().all(|byte| byte.is_ascii_hexdigit()) =>
            {
                commit_count += 1;
            }
            ["group", library, directory, compiled, selection] => {
                assert!(
                    libraries.insert(*library),
                    "duplicate static library in {SOURCE_PLAN_PATH}: {library}"
                );
                assert!(
                    directories.insert(*directory),
                    "duplicate source directory in {SOURCE_PLAN_PATH}: {directory}"
                );
                assert_safe_relative(directory, "source directory");

                let files: Vec<&str> = compiled.split(',').collect();
                assert!(
                    !files.is_empty(),
                    "empty compiled file list for {directory}"
                );
                let mut unique_files = HashSet::new();
                for file in &files {
                    assert!(
                        !file.is_empty()
                            && file.ends_with(".c")
                            && !file.contains('/')
                            && !file.contains('\\'),
                        "compiled source must be a local .c file: {file}"
                    );
                    assert!(
                        unique_files.insert(*file),
                        "duplicate compiled source for {directory}: {file}"
                    );
                }

                if let Some(vendored) = selection.strip_prefix("files:") {
                    let selected: HashSet<&str> = vendored.split(',').collect();
                    assert!(
                        files.iter().all(|file| selected.contains(file)),
                        "compiled file is absent from explicit vendor selection for {directory}"
                    );
                } else {
                    assert_eq!(
                        *selection, "tree",
                        "invalid vendor selection for {directory}"
                    );
                }

                groups.push(SourceGroup {
                    library,
                    directory,
                    files,
                });
            }
            _ => panic!("invalid {SOURCE_PLAN_PATH} line {}: {raw_line}", index + 1),
        }
    }

    assert_eq!(upstream_count, 1, "source plan must contain one upstream");
    assert_eq!(
        commit_count, 1,
        "source plan must contain one full commit SHA"
    );
    assert_eq!(groups.len(), 6, "source plan must contain six build groups");
    groups
}

fn assert_safe_relative(value: &str, context: &str) {
    let path = Path::new(value);
    assert!(
        !value.contains('\\')
            && !path.is_absolute()
            && path
                .components()
                .all(|component| matches!(component, Component::Normal(_))),
        "unsafe {context}: {value}"
    );
}

fn compile_group(vendor_root: &Path, group: &SourceGroup<'_>) {
    let directory = vendor_root.join(group.directory);
    if !directory.is_dir() {
        panic!(
            "missing pinned PQClean source directory: {}",
            directory.display()
        );
    }

    println!("cargo:warning=PQClean C source root: {}", group.directory);
    println!("cargo:rerun-if-changed={}", directory.display());

    let mut build = cc::Build::new();
    build
        .include(&directory)
        .include(vendor_root.join("common"))
        .warnings(false)
        .flag_if_supported("-std=c99")
        .flag_if_supported("/std:c11");

    for file in &group.files {
        let source = directory.join(file);
        if !source.is_file() {
            panic!("missing pinned PQClean source file: {}", source.display());
        }
        println!("cargo:rerun-if-changed={}", source.display());
        build.file(source);
    }

    build.compile(group.library);
}
