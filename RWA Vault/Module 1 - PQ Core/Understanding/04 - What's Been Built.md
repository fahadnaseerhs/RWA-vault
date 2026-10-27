---
tags: [rwa-vault, m1, explainer]
---
# What's Been Built (Stages 0–3)

This page summarises what has actually been implemented so far in Module 1 — not as a task checklist, but as a narrative of what exists and why.

## Stage 0 — Decision follow-through (3 tasks)

**What happened:** Before writing any code, the team made foundational decisions and recorded them as Architecture Decision Records (ADRs):

- **ADR 0002** selected the six algorithms and justified why each one was chosen
- **ADR 0003** chose PQClean over liboqs as the underlying C implementation
- **ADR 0004** committed to vendoring the C sources directly rather than using a system-installed library

These decisions shaped everything that followed. They're not code, but they're essential — without them, every subsequent implementation question would have been an argument.

## Stage 1 — Crate skeleton and Falcon slice (18 tasks)

**What happened:** The Rust crate was created from scratch, with the full build pipeline working end to end for one algorithm (Falcon-512).

What this stage produced:
- The monorepo structure: `packages/pq-core/native/` for Rust, `packages/pq-core/src/` for TypeScript
- PQClean's Falcon-padded-512 C sources vendored into the tree, compiled via `build.rs`
- A working WASM build: `wasm-pack build` produces a `.wasm` module that runs in a browser
- A working native build: `cargo build` produces an `.rlib` that other crates can depend on
- The `PqAlgorithm` enum, `PqError` type, and `AlgorithmMetadata` table — all of which are used throughout the rest of the module
- Entropy validation: the `rng` module probes the platform's CSPRNG and refuses to operate if it's unavailable (fail-closed)
- Secret wrappers (`PrivateKey`, `SharedSecret`) that zeroize memory on drop and don't implement `Debug` or `Clone`
- Rust tests: keygen → sign → verify round-trip for Falcon, metadata table assertions, error variant checks

**In plain English:** After this stage, you could generate a Falcon-512 key pair, sign a message, and verify the signature — in both a browser (via WASM) and a Rust test harness. The crate had its shape.

## Stage 2 — Full algorithm matrix (17 tasks)

**What happened:** The remaining five algorithms were added to the crate, bringing the total to all six primitives.

What this stage produced:
- ML-DSA-44 and ML-DSA-65 implementations (PQClean vendored C)
- SLH-DSA-SHA2-128s implementation (Rust `slh-dsa` crate — pure Rust, no C)
- ML-KEM-768 and ML-KEM-1024 implementations (PQClean vendored C)
- The `SignatureScheme` and `KemScheme` traits with `algorithms.rs` as the dispatch layer
- The `metadata.rs` table expanded to all six algorithms with compile-time size assertions
- ADR 0006 recording the exact byte lengths (the "byte encoding contract")
- ADR 0007 recording the fail-closed entropy probe and KAT (Known-Answer Test) feature gate
- WASM exports expanded from Falcon-only to all six primitives
- Round-trip tests for every algorithm: keygen → sign → verify, keygen → encapsulate → decapsulate

**In plain English:** After this stage, all six algorithms worked in Rust. You could generate keys, sign, verify, encapsulate, and decapsulate for any of them. The byte sizes were locked down and verified at compile time. But there was no Node.js addon yet — the only way to use these was from Rust directly or via the raw WASM exports.

## Stage 3 — Runtime adapters (15 tasks)

**What happened:** The gap between "Rust code that works" and "TypeScript code that the rest of the project can use" was bridged.

What this stage produced:

### TypeScript layer
- **`src/types.ts`** — The `PqCoreApi` interface and all type definitions extracted into a clean, importable module. Algorithm identifiers are union types (`PqSignatureAlgorithm`, `PqKemAlgorithm`) so TypeScript catches errors at compile time.
- **`src/errors.ts`** — Nine error classes mirroring the Rust error variants exactly. A factory function `pqErrorFromCode("MALFORMED_KEY")` creates the right class. This means the rest of the project can `catch` specific error types.
- **`src/metadata.ts`** — TypeScript-side metadata tables mirroring the Rust `ALGORITHM_METADATA`. Single source of truth for byte sizes on the TS side.
- **`src/native.ts`** — `createNativeAdapter()` factory. Loads the `.node` addon, wraps every call, parses the `[CODE] message` error format back into typed errors.
- **`src/wasm.ts`** — `createWasmAdapter()` factory. Lazy-loads the WASM module via dynamic import, copies bytes out of WASM memory, frees WASM objects after use.
- **`src/index.ts`** — Clean re-export hub. Everything is accessible from the package root.

### Native addon (`native/napi/`)
- A separate Rust crate that compiles to a `.node` native addon
- Six `AsyncTask` structs so crypto runs on the libuv thread pool (non-blocking)
- SLH-DSA sign explicitly rejected (ADR 0005 — offline only)
- Error format: `[ERROR_CODE] Human-readable message`

### WASM expansion (`native/src/wasm.rs`)
- Expanded from Falcon-only (Stage 1) to all six primitives
- Generic output structs (`WasmKeyPair`, `WasmEncapsulation`)

### Offline CLI (`native/pqctl/`)
- Standalone binary for SLH-DSA root ceremonies
- Three commands: `keygen`, `sign`, `verify`
- Hardcoded to SLH-DSA-SHA2-128s — this tool does one thing and does it safely

### Package configuration
- Subpath exports in `package.json` (`./native`, `./wasm`, `./errors`, `./types`)
- Build scripts for all targets (`build:addon`, `build:pqctl`, `build:wasm`)

**In plain English:** After this stage, any TypeScript code in the monorepo can `import { createNativeAdapter } from "@rwa-vault/pq-core/native"`, call `adapter.keygen("falcon-512")`, and get back a typed `PqKeyPair` with proper error handling. The API is the same whether you're in Node.js or a browser. Module 2 (PQ-PKI & Envelope) can now start building on top of this.

---

Prev: [[03 - Architecture]] · Next: [[05 - What Remains]] · Up: [[Module 1 - PQ Core]]
