---
tags: [rwa-vault, m1, running]
---
# Test Commands

## 1. Rust unit tests (core crate)

```bash
cargo test --manifest-path packages/pq-core/native/Cargo.toml
```

**What it does:** Runs all Rust tests in the core crate. These include:

- **Round-trip tests for all six algorithms:**
  - Signatures: keygen → sign → verify (Falcon-512, ML-DSA-44, ML-DSA-65, SLH-DSA-SHA2-128s)
  - KEMs: keygen → encapsulate → decapsulate (ML-KEM-768, ML-KEM-1024)
- **Metadata table assertions:** Verifies the `ALGORITHM_METADATA` table matches ADR 0006 exactly (all byte sizes, wire codes, algorithm identifiers)
- **Error variant tests:** Asserts that specific error conditions produce the expected `PqError` variant (e.g. passing a KEM key to a signature function → `UnsupportedAlgorithm`)
- **Secret wrapper safety:** Compile-fail doctests that verify `PrivateKey` and `SharedSecret` don't implement `Debug` or `Clone`
- **Cross-verification:** A signature produced by algorithm X can only be verified by algorithm X (not by a different algorithm)

**Expected output:**
```
running N tests
test algorithms::tests::falcon_512_round_trip ... ok
test algorithms::tests::ml_dsa_44_round_trip ... ok
test algorithms::tests::ml_dsa_65_round_trip ... ok
test algorithms::tests::slh_dsa_sha2_128s_round_trip ... ok
test algorithms::tests::ml_kem_768_round_trip ... ok
test algorithms::tests::ml_kem_1024_round_trip ... ok
test metadata::tests::table_matches_adr_0006 ... ok
...
test result: ok. N passed; 0 failed; 0 ignored
```

**What it means practically:** Every algorithm produces valid key pairs, every signature verifies correctly, every KEM exchange produces matching shared secrets. The byte sizes locked in ADR 0006 are correct. If any test fails, it means either:
- A vendored C source was modified (check `native/vendor/`)
- The Rust toolchain changed (check `native/rust-toolchain.toml` — should be 1.81.0)
- A metadata constant was changed without updating the implementation

**Time:** ~5–15 seconds. SLH-DSA is the slowest (signing takes ~200 ms).

---

## 2. TypeScript typecheck

```bash
pnpm --filter @rwa-vault/pq-core typecheck
```

**What it does:** Runs `tsc --build` to verify all TypeScript source files type-check correctly without producing compilation errors.

**Expected output:** No output (silence = success). If there are errors, TypeScript prints them with file paths and line numbers.

**What it means practically:** The `PqCoreApi` interface, error classes, metadata tables, and both adapters are all internally consistent. The compiler has verified that:
- Both `createNativeAdapter()` and `createWasmAdapter()` return objects satisfying `PqCoreApi`
- Algorithm union types prevent passing `"ml-kem-768"` to `sign()` (compile-time error)
- Error class hierarchy matches the factory function
- All re-exports from `index.ts` are valid

---

## 3. ESLint

```bash
pnpm --filter @rwa-vault/pq-core lint
```

**What it does:** Runs ESLint on the `src/` directory to check for code style violations, unused imports, and common mistakes.

**Expected output:** No output (silence = success). If there are warnings or errors, ESLint prints them with file paths and rule names.

---

## 4. TypeScript contract tests (placeholder)

```bash
pnpm --filter @rwa-vault/pq-core test
```

This runs:
```bash
node --test dist/__tests__/contract.test.js
```

**Current status:** The test file doesn't exist yet — this is part of S3-13 (deferred to Stage 4/7 when CI is set up). Running this now will error with "file not found."

**What it will do eventually:** End-to-end tests that load the native adapter, call every API method, and verify the outputs match expected types and byte sizes. These tests exercise the full stack: TypeScript → napi addon → Rust core → vendored C.

---

## 5. Verify the napi addon compiles

```bash
cargo build --release --manifest-path packages/pq-core/native/napi/Cargo.toml
```

**What it does:** Compiles the napi addon crate. This is not a "test" in the traditional sense, but it verifies that:
- The addon crate correctly depends on the core crate
- All `#[napi]` function signatures are valid
- The `AsyncTask` implementations compile correctly
- The SLH-DSA sign rejection (ADR 0005) is in place

**Expected output:** `Finished release profile` line with no errors.

**What it means practically:** If this compiles, the addon will load in Node.js. If it fails, the napi-rs version or Rust toolchain may have changed.

---

## 6. Verify the pqctl binary compiles

```bash
cargo build --release --manifest-path packages/pq-core/native/pqctl/Cargo.toml
```

**Expected output:** `Finished release profile` line.

**What it means practically:** The offline SLH-DSA tool is buildable. You can then test it manually (see [[03 - pqctl Usage]]).

---

## Summary table

| Command | What it tests | Time | Should pass now? |
|---------|--------------|------|-----------------|
| `cargo test --manifest-path packages/pq-core/native/Cargo.toml` | Rust core: all 6 algorithms, metadata, errors | ~5–15s | Yes |
| `pnpm --filter @rwa-vault/pq-core typecheck` | TypeScript types consistency | ~2s | Yes |
| `pnpm --filter @rwa-vault/pq-core lint` | ESLint code quality | ~1s | Yes |
| `pnpm --filter @rwa-vault/pq-core test` | TS contract tests (placeholder) | — | No (not yet written) |
| `cargo build --release -p rwa-vault-pq-core-napi` | Addon compiles | ~10–30s | Yes |
| `cargo build --release -p rwa-vault-pq-core-pqctl` | pqctl compiles | ~10–30s | Yes |

---

Prev: [[01 - Build Commands]] · Next: [[03 - pqctl Usage]] · Up: [[Module 1 - PQ Core]]
