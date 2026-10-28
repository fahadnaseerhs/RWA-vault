---
tags: [rwa-vault, m1, explainer]
---
# Architecture

This page explains how PQ Core is structured — from the Rust crate at the bottom to the TypeScript API at the top.

## Layer diagram

```
Layer 4 — TypeScript API
  ┌────────────────────────────────────────────────┐
  │  PqCoreApi interface (src/types.ts)            │
  │  keygen · sign · verify · metadata             │
  │  kemKeygen · encapsulate · decapsulate · kemMd  │
  └─────────────┬──────────────────┬───────────────┘
                │                  │
Layer 3 — TypeScript adapters
  ┌─────────────┴──────┐  ┌───────┴───────────────┐
  │  src/native.ts     │  │  src/wasm.ts           │
  │  createNative      │  │  createWasm            │
  │  Adapter()         │  │  Adapter()             │
  │  loads .node addon │  │  lazy-loads WASM pkg   │
  └─────────┬──────────┘  └───────┬───────────────┘
            │                     │
Layer 2 — FFI boundary
  ┌─────────┴──────────┐  ┌──────┴────────────────┐
  │  native/napi/      │  │  native/src/wasm.rs    │
  │  napi-rs addon     │  │  wasm-bindgen exports  │
  │  AsyncTask structs │  │  #[wasm_bindgen] fns   │
  └─────────┬──────────┘  └───────┬───────────────┘
            │                     │
            └─────────┬───────────┘
                      │
Layer 1 — Rust core
  ┌───────────────────┴────────────────────────────┐
  │  native/src/                                   │
  │  algorithms.rs — dispatch (keygen, sign, ...)  │
  │  metadata.rs   — ADR 0006 byte contract        │
  │  types.rs      — PublicKey, PrivateKey, etc.   │
  │  error.rs      — PqError with 9 variants       │
  │  traits.rs     — SignatureScheme, KemScheme     │
  │  falcon/       — PQClean vendored C + FFI      │
  │  mldsa/        — PQClean vendored C + FFI      │
  │  mlkem/        — PQClean vendored C + FFI      │
  │  slhdsa/       — Rust slh-dsa crate wrapper    │
  │  rng.rs        — fail-closed entropy (ADR 007) │
  └────────────────────────────────────────────────┘
```

## Layer 1: Rust core (`native/src/`)

This is where cryptographic operations actually happen. One crate, two compilation targets.

### Module layout

- **`algorithms.rs`** — The dispatch layer. Functions like `keygen(PqAlgorithm) -> KeyPair` route to the correct implementation based on the algorithm enum. This is where the `SignatureScheme` and `KemScheme` traits are called.
- **`traits.rs`** — Two traits defining the operation contract: `SignatureScheme` (keygen, sign, verify) and `KemScheme` (keygen, encapsulate, decapsulate). Each algorithm module implements one of these.
- **`types.rs`** — Wrapper types for public keys, private keys, signatures, ciphertexts, and shared secrets. Private types implement `Zeroize` (cleared from memory on drop) and deliberately do not implement `Debug` or `Clone` to prevent accidental logging or copying.
- **`metadata.rs`** — The `ALGORITHM_METADATA` const array with exact byte sizes for all six algorithms. Compile-time assertions verify these sizes against the actual C/Rust implementation constants. If a size is wrong, the crate does not compile.
- **`error.rs`** — `PqError` enum with 9 variants (e.g. `UnsupportedAlgorithm`, `MalformedKey`, `RngFailure`). Each variant has a stable string `code()` used for cross-FFI error mapping.
- **`rng.rs`** — Entropy source. On native: OS-provided (`getrandom`). On WASM: `crypto.getRandomValues()`. Fail-closed: if the entropy source fails, operations error rather than falling back to weak randomness.
- **`falcon/`, `mldsa/`, `mlkem/`** — Vendored PQClean C reference implementations compiled via the `cc` crate in `build.rs`. Each module implements the relevant trait.
- **`slhdsa/`** — Uses the pure-Rust `slh-dsa` crate (not vendored C). Implements `SignatureScheme`.

### Compilation targets

The crate has two `crate-type` entries in `Cargo.toml`:

- **`rlib`** — Rust library, used by the napi addon crate and pqctl binary
- **`cdylib`** — Compiled to a `.wasm` module by `wasm-pack`

The `#[cfg(target_arch = "wasm32")]` gate controls which modules are included in each target. The WASM build includes `wasm.rs` (the `wasm_bindgen` exports); the native build does not.

## Layer 2: FFI boundaries

### Native path: napi-rs addon (`native/napi/`)

A separate Rust crate (`rwa-vault-pq-core-napi`) that depends on the core crate. It exposes #[napi] functions that Node.js can call directly.

Key design:
- **AsyncTask** structs for every operation — crypto runs on the libuv thread pool, never blocking the event loop.
- Error mapping: Rust `PqError` → napi Error with message `[CODE] description`. The TypeScript adapter parses this format back into typed error classes.
- **ADR 0005 enforcement:** `sign("slh-dsa-sha2-128s", ...)` is rejected at this layer. The addon will not sign with SLH-DSA.
- Stateless: no global mutable state. Every call receives its inputs and returns outputs.

### WASM path: wasm-bindgen (`native/src/wasm.rs`)

`#[wasm_bindgen]` functions that compile into the `.wasm` module loaded by browsers. The WASM adapter returns `WasmKeyPair` and `WasmEncapsulation` structs. The TypeScript adapter copies bytes out of them and then `free()`s the WASM memory to avoid leaks.

## Layer 3: TypeScript adapters (`src/native.ts`, `src/wasm.ts`)

Two factory functions:
- `createNativeAdapter()` — returns a `PqCoreApi` backed by the .node addon
- `createWasmAdapter()` — returns a `PqCoreApi` backed by the WASM module

Both return the same interface. The consumer (Module 2, services, etc.) picks the right adapter at startup and never thinks about the FFI details again.

Error mapping: both adapters catch FFI errors and convert them to the typed error classes in `src/errors.ts` (9 classes matching the 9 Rust error variants exactly).

## Layer 4: TypeScript API (`src/types.ts`)

The `PqCoreApi` interface is the public contract:

```typescript
interface PqCoreApi {
  init(): Promise<void>;
  keygen(algorithm: PqSignatureAlgorithm): Promise<PqKeyPair>;
  sign(algorithm: PqSignatureAlgorithm, privateKey: Uint8Array, message: Uint8Array): Promise<Uint8Array>;
  verify(algorithm: PqSignatureAlgorithm, publicKey: Uint8Array, message: Uint8Array, signature: Uint8Array): Promise<boolean>;
  metadata(algorithm: PqSignatureAlgorithm): PqSignatureMetadata;
  kemKeygen(algorithm: PqKemAlgorithm): Promise<PqKeyPair>;
  encapsulate(algorithm: PqKemAlgorithm, publicKey: Uint8Array): Promise<PqEncapsulation>;
  decapsulate(algorithm: PqKemAlgorithm, privateKey: Uint8Array, ciphertext: Uint8Array): Promise<Uint8Array>;
  kemMetadata(algorithm: PqKemAlgorithm): PqKemMetadata;
}
```

All methods are async (even metadata, for uniformity in the interface — adapters may return immediately). Algorithm arguments are union types (`"falcon-512" | "ml-dsa-44" | ...`), not bare strings — TypeScript catches typos at compile time.

## The `pqctl` CLI (`native/pqctl/`)

A standalone binary crate for offline SLH-DSA root-ceremony operations. It is **never linked into services**, never compiled to WASM, and never exposed via the Node addon. It exists solely to generate SLH-DSA keys and sign files on an air-gapped machine.

## Package exports

The npm package `@rwa-vault/pq-core` exposes subpath exports so consumers can import only what they need:

```
@rwa-vault/pq-core          → types, errors, metadata, both adapter factories
@rwa-vault/pq-core/native   → createNativeAdapter only
@rwa-vault/pq-core/wasm     → createWasmAdapter only
@rwa-vault/pq-core/errors   → error classes
@rwa-vault/pq-core/types    → type definitions
```

---

Prev: [[02 - The Six Primitives]] · Next: [[04 - What's Been Built]] · Up: [[Module 1 - PQ Core]]
