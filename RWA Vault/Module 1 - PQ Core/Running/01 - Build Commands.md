---
tags: [rwa-vault, m1, running]
---
# Build Commands

All commands assume you're in the repository root (`RWA vault/`). The Rust toolchain (1.81.0) and pnpm must be installed.

## 1. Install Node dependencies

```bash
pnpm install
```

**What it does:** Installs all npm packages across the monorepo (pnpm workspaces). Needed once, or after pulling new changes that modify any `package.json`.

**Expected output:** A tree of installed packages. No errors. If you see peer dependency warnings, those are typically fine.

---

## 2. Build the Rust core crate (native)

```bash
cargo build --release --manifest-path packages/pq-core/native/Cargo.toml
```

**What it does:** Compiles the core Rust crate (`rwa-vault-pq-core`) into a native `.rlib` library. This step:
- Runs `build.rs`, which compiles the vendored PQClean C sources via the `cc` crate
- Parses `api.h` headers to extract exact key/signature byte sizes
- Generates `pqclean_sizes.rs` with compile-time constants
- Compiles all six algorithm implementations
- Runs compile-time assertions verifying that the metadata table sizes match the actual implementation sizes

**Expected output:**
```
   Compiling rwa-vault-pq-core v0.1.0 (packages\pq-core\native)
    Finished `release` profile [optimized] target(s) in Xs
```

**What it means:** The core cryptographic library compiled successfully. All six algorithms are available. The metadata byte sizes are correct (verified at compile time). If this fails, it's usually a toolchain issue — check that `rustc --version` says `1.81.0`.

---

## 3. Build the Node.js addon (napi-rs)

```bash
cargo build --release --manifest-path packages/pq-core/native/napi/Cargo.toml
```

**What it does:** Compiles the napi-rs crate (`rwa-vault-pq-core-napi`) into a `.node` native addon file. This crate depends on the core crate and wraps its functions for use from Node.js via the N-API interface.

**Expected output:**
```
   Compiling rwa-vault-pq-core v0.1.0 (packages\pq-core\native)
   Compiling rwa-vault-pq-core-napi v0.1.0 (packages\pq-core\native\napi)
    Finished `release` profile [optimized] target(s) in Xs
```

The `.node` file is produced at `target/release/rwa_vault_pq_core_napi.node` (or `.dll`/`.so`/`.dylib` depending on OS). For the TypeScript adapter to load it, it needs to be at `packages/pq-core/pq-core.node`.

**What it means:** Node.js services can now load this addon and call the PQ cryptographic functions. All operations run on the libuv thread pool (non-blocking).

**Or use the npm script shorthand:**
```bash
pnpm --filter @rwa-vault/pq-core build:addon
```

---

## 4. Build the WASM module

```bash
pnpm --filter @rwa-vault/pq-core build:wasm
```

This runs:
```bash
wasm-pack build native --target web --out-dir ../pkg --release --locked
```

**What it does:** Compiles the Rust core crate to WebAssembly. The `--target web` flag produces ES module bindings (no bundler required). Output goes to `packages/pq-core/pkg/`.

**Prerequisites:** Install wasm-pack first:
```bash
cargo install wasm-pack
```

And ensure the WASM target is available:
```bash
rustup target add wasm32-unknown-unknown
```

**Expected output:**
```
[INFO]: Compiling to Wasm...
[INFO]: Optional fields missing from Cargo.toml: ...
[INFO]: Installing wasm-bindgen...
[INFO]: Optimizing wasm binaries with `wasm-opt`...
[INFO]: :-) Done in Xs
[INFO]: Your wasm pkg is ready to publish at packages/pq-core/pkg
```

**What it means:** The `packages/pq-core/pkg/` directory now contains:
- `rwa_vault_pq_core.js` — JavaScript glue code
- `rwa_vault_pq_core_bg.wasm` — the compiled WASM binary
- `rwa_vault_pq_core.d.ts` — TypeScript type declarations

Browsers can import this module and run all six PQ algorithms client-side. The private key never leaves the device.

---

## 5. Build the pqctl CLI

```bash
pnpm --filter @rwa-vault/pq-core build:pqctl
```

This runs:
```bash
cargo build --release --manifest-path packages/pq-core/native/pqctl/Cargo.toml
```

**What it does:** Compiles the `pqctl` standalone binary for offline SLH-DSA root ceremonies.

**Expected output:**
```
   Compiling rwa-vault-pq-core v0.1.0 (packages\pq-core\native)
   Compiling rwa-vault-pq-core-pqctl v0.1.0 (packages\pq-core\native\pqctl)
    Finished `release` profile [optimized] target(s) in Xs
```

The binary is at `target/release/rwa-vault-pq-core-pqctl` (or `.exe` on Windows).

**What it means:** You now have a CLI that can generate SLH-DSA-SHA2-128s keys and sign files offline. This is the tool used during root-ceremony operations on an air-gapped machine.

---

## 6. Build the TypeScript

```bash
pnpm --filter @rwa-vault/pq-core build
```

This runs:
```bash
tsc --build tsconfig.json
```

**What it does:** Compiles the TypeScript source files (`src/*.ts`) into JavaScript (`dist/*.js`) and type declarations (`dist/*.d.ts`).

**Expected output:** No output on success (TypeScript compiler is silent when everything is clean). The `dist/` directory is populated.

**What it means:** The npm package is ready to be consumed by other packages in the monorepo. Other packages can now:
```typescript
import { createNativeAdapter } from "@rwa-vault/pq-core/native";
import { PqSignatureAlgorithm } from "@rwa-vault/pq-core/types";
```

---

## Build everything at once

There's no single "build all" command yet (that comes in Stage 7), but the sequence is:

```bash
pnpm install
cargo build --release --manifest-path packages/pq-core/native/Cargo.toml
cargo build --release --manifest-path packages/pq-core/native/napi/Cargo.toml
pnpm --filter @rwa-vault/pq-core build:wasm
cargo build --release --manifest-path packages/pq-core/native/pqctl/Cargo.toml
pnpm --filter @rwa-vault/pq-core build
```

---

Next: [[02 - Test Commands]] · Up: [[Module 1 - PQ Core]]
