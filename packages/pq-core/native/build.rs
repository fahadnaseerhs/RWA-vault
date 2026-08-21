use std::collections::HashSet;
use std::fmt::Write as _;
use std::fs;
use std::path::{Component, Path, PathBuf};

const VENDOR_ROOT: &str = "vendor/pqclean";
const WASM_INCLUDE_ROOT: &str = "wasm-include";
const SOURCE_PLAN_PATH: &str = "pqclean-source-plan.txt";
const SOURCE_PLAN: &str = include_str!("pqclean-source-plan.txt");
const GENERATED_SIZES_FILE: &str = "pqclean_sizes.rs";
const WASM_AUDIT_FILE: &str = "wasm-c-audit.txt";
const WASM_C_FLAGS: &[&str] = &[
    "--target=wasm32-unknown-unknown",
    // Rust 1.81 does not enable reference-types for this target. Newer Clang
    // enables it by default, and a mixed-feature module cannot be processed by
    // wasm-bindgen because its externref support exports were not emitted.
    "-mno-reference-types",
    "-nostdlibinc",
    "-ffreestanding",
    "-std=c99",
];

struct SourceGroup<'a> {
    library: &'a str,
    directory: &'a str,
    files: Vec<&'a str>,
}

struct SizeMacro {
    rust_name: &'static str,
    header: &'static str,
    c_name: &'static str,
}

struct WasmAuditGroup {
    library: String,
    compiler: PathBuf,
    arguments: Vec<String>,
    sources: Vec<PathBuf>,
}

const SIZE_MACROS: &[SizeMacro] = &[
    SizeMacro {
        rust_name: "FALCON_PADDED_512_PUBLIC_KEY_BYTES",
        header: "crypto_sign/falcon-padded-512/clean/api.h",
        c_name: "PQCLEAN_FALCONPADDED512_CLEAN_CRYPTO_PUBLICKEYBYTES",
    },
    SizeMacro {
        rust_name: "FALCON_PADDED_512_SECRET_KEY_BYTES",
        header: "crypto_sign/falcon-padded-512/clean/api.h",
        c_name: "PQCLEAN_FALCONPADDED512_CLEAN_CRYPTO_SECRETKEYBYTES",
    },
    SizeMacro {
        rust_name: "FALCON_PADDED_512_SIGNATURE_BYTES",
        header: "crypto_sign/falcon-padded-512/clean/api.h",
        c_name: "PQCLEAN_FALCONPADDED512_CLEAN_CRYPTO_BYTES",
    },
    SizeMacro {
        rust_name: "ML_DSA_44_PUBLIC_KEY_BYTES",
        header: "crypto_sign/ml-dsa-44/clean/api.h",
        c_name: "PQCLEAN_MLDSA44_CLEAN_CRYPTO_PUBLICKEYBYTES",
    },
    SizeMacro {
        rust_name: "ML_DSA_44_SECRET_KEY_BYTES",
        header: "crypto_sign/ml-dsa-44/clean/api.h",
        c_name: "PQCLEAN_MLDSA44_CLEAN_CRYPTO_SECRETKEYBYTES",
    },
    SizeMacro {
        rust_name: "ML_DSA_44_SIGNATURE_BYTES",
        header: "crypto_sign/ml-dsa-44/clean/api.h",
        c_name: "PQCLEAN_MLDSA44_CLEAN_CRYPTO_BYTES",
    },
    SizeMacro {
        rust_name: "ML_DSA_65_PUBLIC_KEY_BYTES",
        header: "crypto_sign/ml-dsa-65/clean/api.h",
        c_name: "PQCLEAN_MLDSA65_CLEAN_CRYPTO_PUBLICKEYBYTES",
    },
    SizeMacro {
        rust_name: "ML_DSA_65_SECRET_KEY_BYTES",
        header: "crypto_sign/ml-dsa-65/clean/api.h",
        c_name: "PQCLEAN_MLDSA65_CLEAN_CRYPTO_SECRETKEYBYTES",
    },
    SizeMacro {
        rust_name: "ML_DSA_65_SIGNATURE_BYTES",
        header: "crypto_sign/ml-dsa-65/clean/api.h",
        c_name: "PQCLEAN_MLDSA65_CLEAN_CRYPTO_BYTES",
    },
    SizeMacro {
        rust_name: "ML_KEM_768_PUBLIC_KEY_BYTES",
        header: "crypto_kem/ml-kem-768/clean/api.h",
        c_name: "PQCLEAN_MLKEM768_CLEAN_CRYPTO_PUBLICKEYBYTES",
    },
    SizeMacro {
        rust_name: "ML_KEM_768_SECRET_KEY_BYTES",
        header: "crypto_kem/ml-kem-768/clean/api.h",
        c_name: "PQCLEAN_MLKEM768_CLEAN_CRYPTO_SECRETKEYBYTES",
    },
    SizeMacro {
        rust_name: "ML_KEM_768_CIPHERTEXT_BYTES",
        header: "crypto_kem/ml-kem-768/clean/api.h",
        c_name: "PQCLEAN_MLKEM768_CLEAN_CRYPTO_CIPHERTEXTBYTES",
    },
    SizeMacro {
        rust_name: "ML_KEM_768_SHARED_SECRET_BYTES",
        header: "crypto_kem/ml-kem-768/clean/api.h",
        c_name: "PQCLEAN_MLKEM768_CLEAN_CRYPTO_BYTES",
    },
    SizeMacro {
        rust_name: "ML_KEM_1024_PUBLIC_KEY_BYTES",
        header: "crypto_kem/ml-kem-1024/clean/api.h",
        c_name: "PQCLEAN_MLKEM1024_CLEAN_CRYPTO_PUBLICKEYBYTES",
    },
    SizeMacro {
        rust_name: "ML_KEM_1024_SECRET_KEY_BYTES",
        header: "crypto_kem/ml-kem-1024/clean/api.h",
        c_name: "PQCLEAN_MLKEM1024_CLEAN_CRYPTO_SECRETKEYBYTES",
    },
    SizeMacro {
        rust_name: "ML_KEM_1024_CIPHERTEXT_BYTES",
        header: "crypto_kem/ml-kem-1024/clean/api.h",
        c_name: "PQCLEAN_MLKEM1024_CLEAN_CRYPTO_CIPHERTEXTBYTES",
    },
    SizeMacro {
        rust_name: "ML_KEM_1024_SHARED_SECRET_BYTES",
        header: "crypto_kem/ml-kem-1024/clean/api.h",
        c_name: "PQCLEAN_MLKEM1024_CLEAN_CRYPTO_BYTES",
    },
];

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed={SOURCE_PLAN_PATH}");

    let manifest_root = PathBuf::from(
        std::env::var_os("CARGO_MANIFEST_DIR").expect("Cargo must provide CARGO_MANIFEST_DIR"),
    );
    let vendor_root = manifest_root.join(VENDOR_ROOT);
    let out_dir = PathBuf::from(std::env::var_os("OUT_DIR").expect("Cargo must provide OUT_DIR"));
    if !vendor_root.is_dir() {
        panic!(
            "vendored PQClean sources are missing; run scripts/vendor-pqclean.py from the repository root"
        );
    }

    generate_implementation_sizes(&vendor_root, &out_dir);

    let target_arch = std::env::var("CARGO_CFG_TARGET_ARCH").unwrap_or_default();
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    let is_freestanding_wasm = target_arch == "wasm32" && target_os == "unknown";
    let groups = parse_source_plan();
    let wasm_compiler = is_freestanding_wasm.then(|| {
        std::env::var("WASM32_UNKNOWN_UNKNOWN_CLANG").unwrap_or_else(|_| "clang".to_owned())
    });

    let mut wasm_audit_groups = Vec::new();
    for group in groups {
        if let Some(audit_group) = compile_group(
            &manifest_root,
            &vendor_root,
            &group,
            wasm_compiler.as_deref(),
        ) {
            wasm_audit_groups.push(audit_group);
        }
    }

    if wasm_compiler.is_some() {
        write_wasm_audit_manifest(&out_dir, &wasm_audit_groups);
    }

    // `common/randombytes.c` is deliberately not in the shared source plan. The
    // Rust FFI layer owns the PQCLEAN_randombytes symbol so production has one
    // target-specific entropy path through `getrandom` (ADR 0007).
}

fn generate_implementation_sizes(vendor_root: &Path, out_dir: &Path) {
    let mut generated = String::from(
        "// @generated by build.rs from the pinned PQClean api.h files.\n\
         // Do not edit this file or transcribe these values by hand.\n\n",
    );
    let mut cached_header: Option<(&str, String)> = None;

    for spec in SIZE_MACROS {
        if cached_header.as_ref().map(|(path, _)| *path) != Some(spec.header) {
            let path = vendor_root.join(spec.header);
            println!("cargo:rerun-if-changed={}", path.display());
            let contents = fs::read_to_string(&path)
                .unwrap_or_else(|error| panic!("failed to read {}: {error}", path.display()));
            cached_header = Some((spec.header, contents));
        }

        let header = &cached_header.as_ref().expect("header was loaded").1;
        let value = parse_decimal_macro(header, spec.c_name, spec.header);
        writeln!(
            generated,
            "pub const {}: usize = {};",
            spec.rust_name, value
        )
        .expect("writing to a String cannot fail");
    }

    fs::write(out_dir.join(GENERATED_SIZES_FILE), generated)
        .expect("failed to write generated PQClean size constants");
}

fn parse_decimal_macro(header: &str, name: &str, source: &str) -> usize {
    header
        .lines()
        .find_map(|line| {
            let mut fields = line.split_whitespace();
            match (fields.next(), fields.next(), fields.next(), fields.next()) {
                (Some("#define"), Some(candidate), Some(value), None) if candidate == name => {
                    Some(value.parse::<usize>().unwrap_or_else(|_| {
                        panic!("{name} in {source} must be an unsigned decimal integer")
                    }))
                }
                _ => None,
            }
        })
        .unwrap_or_else(|| panic!("missing implementation size macro {name} in {source}"))
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

fn write_wasm_audit_manifest(out_dir: &Path, groups: &[WasmAuditGroup]) {
    let mut manifest = String::new();
    for group in groups {
        writeln!(manifest, "group\t{}", group.library).expect("String write cannot fail");
        writeln!(manifest, "compiler\t{}", group.compiler.display())
            .expect("String write cannot fail");
        for argument in &group.arguments {
            assert!(!argument.contains('\t'), "compiler argument contains a tab");
            writeln!(manifest, "arg\t{argument}").expect("String write cannot fail");
        }
        for source in &group.sources {
            writeln!(manifest, "source\t{}", source.display()).expect("String write cannot fail");
        }
        writeln!(manifest, "end\t{}", group.library).expect("String write cannot fail");
    }

    let audit_path = out_dir.join(WASM_AUDIT_FILE);
    fs::write(&audit_path, manifest).expect("failed to write WASM C audit manifest");
    println!(
        "cargo:warning=PQClean WASM audit manifest: {}",
        audit_path.display()
    );
}

fn compile_group(
    manifest_root: &Path,
    vendor_root: &Path,
    group: &SourceGroup<'_>,
    wasm_compiler: Option<&str>,
) -> Option<WasmAuditGroup> {
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
        .warnings(false);

    if let Some(compiler) = wasm_compiler {
        build
            .compiler(compiler)
            .include(manifest_root.join(WASM_INCLUDE_ROOT));
        for flag in WASM_C_FLAGS {
            build.flag(flag);
        }
        println!("cargo:rerun-if-changed={WASM_INCLUDE_ROOT}");
    } else {
        build
            .flag_if_supported("-std=c99")
            .flag_if_supported("/std:c11");
    }

    let mut sources = Vec::new();
    for file in &group.files {
        let source = directory.join(file);
        if !source.is_file() {
            panic!("missing pinned PQClean source file: {}", source.display());
        }
        println!("cargo:rerun-if-changed={}", source.display());
        build.file(&source);
        sources.push(source);
    }

    let audit_group = wasm_compiler.map(|_| {
        let tool = build.get_compiler();
        WasmAuditGroup {
            library: group.library.to_owned(),
            compiler: tool.path().to_path_buf(),
            arguments: tool
                .args()
                .iter()
                .map(|argument| argument.to_string_lossy().into_owned())
                .collect(),
            sources,
        }
    });
    build.compile(group.library);
    audit_group
}
