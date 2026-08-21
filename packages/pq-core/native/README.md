# `rwa-vault-pq-core` — native post-quantum core

Rust crate wrapping five PQClean schemes, vendored as C at a pinned upstream
commit and compiled by our own `build.rs`, plus SLH-DSA from pure Rust.

| Primitive           | Source                                        | Spec     |
| ------------------- | --------------------------------------------- | -------- |
| `falcon-512`        | PQClean `crypto_sign/falcon-padded-512/clean` | Round 3  |
| `ml-dsa-44`         | PQClean `crypto_sign/ml-dsa-44/clean`         | FIPS 204 |
| `ml-dsa-65`         | PQClean `crypto_sign/ml-dsa-65/clean`         | FIPS 204 |
| `ml-kem-768`        | PQClean `crypto_kem/ml-kem-768/clean`         | FIPS 203 |
| `ml-kem-1024`       | PQClean `crypto_kem/ml-kem-1024/clean`        | FIPS 203 |
| `slh-dsa-sha2-128s` | RustCrypto `slh-dsa` 0.1.0                    | FIPS 205 |

The identifier stays `falcon-512` while the implementation is
`falcon-padded-512`: padding is an encoding of the signature, not a different
algorithm, and it buys a fixed 666-byte length. See
[ADR 0003](../../../docs/adr/0003-pq-implementation-sources.md).

## Quick start

```bash
cargo test --locked            # debug: FFI round-trips + differential vectors
cargo test --locked --release  # same, optimised
cargo build --locked --target wasm32-unknown-unknown
```

Requires a C compiler (MSVC Build Tools on Windows, `cc` elsewhere) and
Rust 1.81. The WASM target additionally requires Clang and uses the
`WASM32_UNKNOWN_UNKNOWN_CLANG` environment variable when it is not available as
`clang` on `PATH`.

## Four invariants

These are the properties the tooling exists to hold. Breaking one is a
correctness or provenance bug, not a style question.

### 1. One entropy path

PQClean's schemes call `PQCLEAN_randombytes`. Upstream ships an implementation
in `common/randombytes.c`; **we do not compile it**. `src/rng.rs` defines that
symbol from the `getrandom` crate instead, so the C and Rust halves draw from
one OS CSPRNG on every target ([ADR 0007](../../../docs/adr/0007-random-source.md)).

It fills the buffer or zeroes it and records a sticky operation failure. PQClean's
callers discard the return value (`ml-dsa/sign.c`, `ml-kem/kem.c`,
`ml-kem/indcpa.c`, `falcon/pqclean.c` all call it as a bare statement), so every
safe wrapper clears that status before entering C and checks it afterward. A failed
operation wipes all outputs and returns `RngFailure`; no partial buffer or
zero-seeded result reaches the caller, and there is no retry loop.

**Never add `randombytes.c` to the source plan.**

### 2. The vendored tree is upstream, byte for byte

`vendor/pqclean/` is generated, never hand-edited. Its `PROVENANCE.md` records a
SHA-256 and a Git blob ID per file, and verification compares those against the
objects in the pinned commit — not against the manifest's own arithmetic.

```bash
python scripts/verify-vendor.py    # from the repo root; needs network or a warm cache
```

A tamper that edits a file _and_ rewrites its manifest row still fails, which is
the point: a self-attesting manifest agrees with itself no matter what it covers.

### 3. Vendoring is reproducible on any machine

```bash
python scripts/vendor-pqclean.py   # idempotent: a second run writes nothing
```

Every `git` invocation is pinned to `core.autocrlf=false core.eol=lf`. Without
that, `git archive` honours the operator's Git config and emits CRLF-converted
bytes that no longer match upstream — silently, on Windows, in a way the old
self-attesting manifest could not detect. `.gitattributes` marks the tree
`-text` so checkout cannot undo it either.

### 4. `kat` never reaches an optimised artefact

The `kat` feature gates deterministic seed-taking hooks for conformance
vectors. A `compile_error!` makes an optimised build with it impossible:

```bash
cargo build --release --features kat                              # MUST fail
RUSTFLAGS="-C debug-assertions=on" \
  cargo test --release --features kat                             # conformance job
```

Because the guard is a compile error, a release build that _succeeds_ is itself
proof `kat` was not in its feature set. Only that build produces artefacts.

## Changing which C is compiled

`pqclean-source-plan.txt` is the single source of truth — upstream URL, pinned
commit, and per-scheme file lists. `build.rs` and both Python scripts read it;
no pin is duplicated anywhere else.

```
group|<static-lib>|<upstream-dir>|<compiled .c files>|<tree | files:a,b,c>
```

`tree` vendors the whole upstream directory (headers, LICENSE). `files:` vendors
only the named ones — used for `common/`, which upstream fills with AES, SHA-2,
SP800-185 and AVX2 Keccak we neither compile nor want in the tree.

After editing the plan:

```bash
python scripts/vendor-pqclean.py && python scripts/verify-vendor.py
cargo test --locked --release
```

Then commit the regenerated `vendor/pqclean/` alongside the plan change.

## The differential oracle

Our `build.rs` compiles the C itself. The failure that cannot be caught from
inside this crate is a build that is internally consistent but wrong — wrong
flags, wrong parameter header, a miscompiled reduction. It verifies under our
own verifier because the same defect sits on both sides.

`oracle/` packages the same upstream through a different build system and
compares across a **process boundary**:

```bash
cargo test --locked --release --test differential          # direction 1
cargo run --locked --release --manifest-path oracle/Cargo.toml -- \
  verify target/differential/native-vectors.txt            # direction 2
```

Direction 1 checks the oracle's artefacts against our build using committed
vectors; direction 2 checks our freshly generated artefacts against the oracle.
Both are needed — a signer and verifier wrong in matching ways pass either alone.

> **Why not a dev-dependency?** `pqcrypto-*` vendors PQClean under the same
> symbol names as our build. Linking both into one binary fails on MSVC
> (`LNK2005` / `LNK1169`), and on GNU ld would bind every call to whichever
> archive came first — an implementation silently checked against itself while
> the test reports green. ADR 0003 specifies the dev-dependency form; it is not
> implementable, and this is the deviation.

Regenerate the committed vectors only when the pin changes:

```bash
cargo run --release --manifest-path oracle/Cargo.toml -- generate \
  > tests/vectors/oracle-vectors.txt
```

## Why the tests matter

Native round-trip tests force the linker to resolve and execute the vendored C.
The WASM build additionally exports an address-only link probe that retains every
PQClean operation, including the incremental SHAKE allocation paths, so its strict
linker gate resolves all six static libraries before safe wrappers land. A build
still does not establish cryptographic conformance; that requires
the KAT, ACVP, differential, and cross-runtime vector suites.

## Known constraints

- **WASM C is deliberately freestanding.** `build.rs` invokes Clang with
  `--target=wasm32-unknown-unknown -mno-reference-types -nostdlibinc
-ffreestanding`.
  Complete `stdint.h` and `stddef.h` definitions come from Clang's freestanding
  resource headers; `wasm-include/` owns only the four libc declaration stubs.
  The strict WASM
  build emits its actual compiler, flags, includes, and sources; run
  `scripts/verify-wasm-preprocessor.py` after that build to audit the emitted
  configuration for host-header leakage. Rust's `compiler_builtins` supplies the
  four `mem*` symbols; `wasm_shim.rs` supplies aligned `malloc`/`free` and a
  trapping `exit` for PQClean's incremental SHAKE contexts. The project-owned
  `assert.h` also traps in every profile; defining `NDEBUG` never removes checks.
- **Secret wrappers cannot erase pre-transfer allocation history.** `PrivateKey`
  and `SharedSecret` zeroize the live `Vec` allocation they receive. If a caller
  wrote secret bytes before a reallocation, the allocator may retain an
  unreachable copy in freed memory. Callers must allocate final capacity before
  writing secret material and avoid resizing afterward.
- **The safe WASM slice is intentionally narrow.** Stage 1 exports Falcon
  keygen/sign/verify behind `init()`. Safe ML-DSA, SLH-DSA, and ML-KEM operation
  wrappers belong to later Module 1 stages; their raw C declarations are not an
  application API.
- **`jobserver` is pinned to 0.1.32** in both lockfiles. Newer `cc` pulls
  `jobserver 0.1.35 → getrandom 0.4.3`, which needs Edition 2024 and will not
  parse on Rust 1.81. Drop the pin when the toolchain moves to ≥1.85.
- **`verify-vendor.py` needs the pinned commit** — network, or a warm cache in
  the system temp directory. There is no offline mode.

## CI

The `pq-native` Linux/Windows matrix in
[`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml) runs formatting,
`clippy -D warnings`, release builds, and debug/release tests. Linux additionally
checks provenance, reproducible vendoring, both `kat` guard directions, and the
oracle. The separate `pq-wasm` job performs strict linking and preprocessing
audits, builds with pinned `wasm-pack`, runs headless Chromium, proves native/WASM
Falcon equivalence in both directions, and compiles the TypeScript package.
