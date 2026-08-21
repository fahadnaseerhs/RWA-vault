# Module 1, Stage 1: Post-Quantum Core Foundation

**Status:** Stage 1 complete on `codex/module-1`.

Stage 1 establishes the first end-to-end vertical slice of Module 1. A
Falcon-padded-512 key can be generated and used to sign in either the native Rust
runtime or browser WebAssembly, and the other runtime verifies the same bytes.
This cross-runtime equivalence is the Stage 1 exit criterion.

Stage 1 does not mean all of Module 1 is complete. The remaining stages add the
other signature and KEM safe wrappers, conformance vectors, stable adapters,
benchmarks, and release evidence described in
[`docs/M1-task-breakdown.md`](../../docs/M1-task-breakdown.md).

## What Stage 1 delivers

- Six canonical algorithm identifiers: four signatures and two ML-KEM variants.
- A pinned, reproducible PQClean source plan with upstream-verifiable provenance.
- Native C compilation on Linux and Windows and freestanding C compilation for
  `wasm32-unknown-unknown`.
- Stable payload-free errors, exact algorithm metadata, generated `api.h` size
  constants, and secret byte wrappers that zeroize on drop.
- A safe Falcon-padded-512 API for key generation, signing, and verification.
- One `getrandom` entropy path: OS CSPRNG natively and Web Crypto in browsers.
- Fail-closed RNG behavior with no retry and no partially filled output exposed.
- A `wasm-bindgen` boundary using `Uint8Array` for keys, messages, and signatures.
- An `init()` entropy probe that keeps cryptographic operations locked after a
  missing, failing, or all-zero Web Crypto backend.
- Bidirectional native/WASM Falcon verification using binary fixtures.
- Required CI definitions for native Linux/Windows and WASM/Chromium checks.

Falcon uses the PQClean `falcon-padded-512` implementation. Its signatures are
always exactly 666 bytes. A well-formed but invalid signature returns `false`;
malformed key or signature lengths return a typed error.

## Stage 1 structure

```text
packages/pq-core/
|-- README.md                     # This Stage 1 operator guide
|-- package.json                  # TypeScript, native, WASM, and browser scripts
|-- src/index.ts                  # Canonical six-algorithm TypeScript types
|-- browser-tests/
|   |-- index.html                # Headless Chromium test page
|   |-- acceptance.mjs            # Entropy, WASM API, and native -> WASM checks
|   `-- run.mjs                   # Local server, binding audit, Chromium runner
`-- native/
    |-- Cargo.toml                # Rust crate and exact dependency pins
    |-- build.rs                  # C plan, generated sizes, WASM audit manifest
    |-- pqclean-source-plan.txt   # Single source of truth for vendored C
    |-- README.md                 # Native build/security details
    |-- examples/
    |   `-- falcon_interop.rs     # Binary native <-> WASM fixture utility
    |-- src/
    |   |-- error.rs              # Closed nine-variant PqError
    |   |-- falcon.rs             # Safe Falcon keygen/sign/verify
    |   |-- metadata.rs           # Six-algorithm byte contract
    |   |-- rng.rs                # OS/Web Crypto entropy and C randombytes symbol
    |   |-- types.rs              # Public and zeroizing secret byte wrappers
    |   |-- wasm.rs               # Uint8Array API and initialization gate
    |   |-- wasm_shim.rs          # WASM malloc/free/exit support
    |   `-- lib.rs                # FFI declarations and crate exports
    |-- tests/
    |   `-- size_assertions.rs    # Live implementation-size checks
    |-- vendor/pqclean/           # Pinned reviewed upstream source subset
    `-- wasm-include/              # Four reviewed freestanding C headers

scripts/
|-- vendor-pqclean.py             # Reproducible vendoring
|-- verify-vendor.py              # Verification against upstream Git objects
|-- verify-wasm-imports.py        # Rejects host C-runtime imports
`-- verify-wasm-preprocessor.py   # Rejects host-header leakage

.github/workflows/ci.yml          # pq-native and pq-wasm required checks
```

Generated directories are intentionally ignored:

- `packages/pq-core/pkg/` contains `wasm-pack` output.
- `packages/pq-core/browser-tests/artifacts/` contains cross-runtime binary
  fixtures.
- `packages/pq-core/native/target/` contains Cargo output.

## Prerequisites

- Rust `1.81.0` and the `wasm32-unknown-unknown` target. The native crate's
  `rust-toolchain.toml` installs both automatically through rustup.
- `wasm-pack 0.13.1`.
- A native C compiler: MSVC Build Tools on Windows or GCC/Clang on Linux.
- Clang with a `wasm32-unknown-unknown` backend for the WASM C build.
- Node.js from `.nvmrc`, pnpm `9.12.0`, Python `3.12+`, and Chrome/Chromium.

From the repository root:

```bash
corepack enable
pnpm install --frozen-lockfile
cargo install wasm-pack --version 0.13.1 --locked
```

## Run native Stage 1

```bash
cd packages/pq-core/native
cargo fmt --check
cargo clippy --locked --all-targets -- -D warnings
cargo build --locked --release
cargo test --locked
cargo test --locked --release
```

The tests cover safe Falcon round trips, exact signature size, bit-flip rejection,
fault-injected entropy failure, secret zeroization, generated size equality, live
implementation output sizes, and the independent differential oracle.

## Build WebAssembly

From `packages/pq-core`:

```bash
WASM32_UNKNOWN_UNKNOWN_CLANG=clang \
RUSTFLAGS="-C link-arg=--error-unresolved-symbols" \
wasm-pack build native --target web --out-dir ../pkg --release --locked
```

PowerShell equivalent:

```powershell
$env:WASM32_UNKNOWN_UNKNOWN_CLANG = "clang"
$env:RUSTFLAGS = "-C link-arg=--error-unresolved-symbols"
wasm-pack build native --target web --out-dir ../pkg --release --locked
```

Then run the two strict WASM audits from the repository root:

```bash
python scripts/verify-wasm-preprocessor.py
python scripts/verify-wasm-imports.py \
  packages/pq-core/native/target/wasm32-unknown-unknown/release/rwa_vault_pq_core.wasm
```

The generated declaration must expose key paths as `Uint8Array`; key material is
never converted through JavaScript strings.

## Run the Stage 1 exit test

Run these commands from the repository root after building WASM:

```bash
# 1. Native signs a binary fixture.
cargo run --locked --release \
  --manifest-path packages/pq-core/native/Cargo.toml \
  --example falcon_interop -- \
  emit packages/pq-core/browser-tests/artifacts

# 2. Chromium verifies native, tests Web Crypto, then signs in WASM.
node packages/pq-core/browser-tests/run.mjs

# 3. Native verifies the WASM-generated signature.
cargo run --locked --release \
  --manifest-path packages/pq-core/native/Cargo.toml \
  --example falcon_interop -- \
  verify packages/pq-core/browser-tests/artifacts
```

The browser runner additionally performs 1,000 Web Crypto draws, rejects missing
and all-zero `crypto.getRandomValues`, proves APIs stay locked after failed
initialization, checks the generated `Uint8Array` declarations, and confirms a
bit-flipped Falcon signature returns `false`.

## Run repository gates

```bash
pnpm lint
pnpm typecheck
pnpm build
pnpm test
pnpm format:check
```

## CI and branch completion

The workflow defines two Stage 1 checks:

- `pq-native (linux)` and `pq-native (windows)` run formatting, Clippy with all
  warnings denied, release builds, and debug/release tests. Linux also verifies
  provenance, reproducible vendoring, KAT containment, and the differential
  oracle.
- `pq-wasm` performs the strict WASM build and audits, runs headless Chromium,
  enforces both directions of the cross-runtime test, and compiles TypeScript.

Work remains on `codex/module-1` until these checks pass and Stage 1 is reviewed.
Only then should this branch be merged into `origin/main`; the branch must not be
used as a substitute for CI or review.
