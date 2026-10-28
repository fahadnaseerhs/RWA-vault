---
tags: [rwa-vault, m1, stage]
stage: 1
status: done
commit: afe574c
---
# M1 Stage 1 — Crate skeleton and Falcon vertical slice ✅

**Goal:** prove a signature can cross the native ↔ WASM boundary (**S1-16**). The freestanding C build for WASM (ADR 0004) was the project's highest technical risk, and this stage settled it.

**Status: 18 / 18 done**. Exit criterion met in both directions: a native signature verifies in the browser, and a WASM signature verifies natively. Falcon signatures are exactly 666 bytes.

## Crate and vendoring
- [x] **S1-01** `native/Cargo.toml`: crate metadata, `cdylib` + `rlib`, deps (`getrandom`, `zeroize`, `slh-dsa`), `kat` feature
- [x] **S1-02** `scripts/vendor-pqclean`: fetch PQClean at the pinned commit (idempotent)
- [x] **S1-03** `vendor/pqclean/PROVENANCE.md` generator: upstream URL, commit SHA and per-file SHA-256. Tampering fails `verify-vendor`
- [x] **S1-04** `build.rs` native compile path: exactly the 6 scheme dirs, no globbing (Linux + Windows)
- [x] **S1-05** `build.rs` freestanding WASM C path plus an audit manifest of the exact compiler, flags and sources
- [x] **S1-06** `wasm_shim.rs`: aligned `malloc`/`free` and a trapping `exit`; wasm32 links with no unresolved symbols

## Core types
- [x] **S1-07** `error.rs`: `PqError` with the 9 variants from ADR 0006; size is 1 byte and no variant carries bytes
- [x] **S1-08** `types.rs`: byte newtypes with `Zeroize` on secrets; `PrivateKey` has no `Debug`/`Display`/`Serialize`
- [x] **S1-09** `metadata.rs`: the size table from ADR 0006 plus `metadata(algorithm)`
- [x] **S1-10** Compile-time assertions that the table matches the sizes in the C `api.h`; a one-byte mismatch is a compile error

## Falcon and RNG
- [x] **S1-11** Falcon-padded-512 FFI + safe wrapper: keygen, sign, verify. A bit flip returns `false`, not an error
- [x] **S1-12** `rng.rs`: native OS CSPRNG; failure surfaces as `RngFailure` with no retry
- [x] **S1-13** WASM RNG via Web Crypto: 1,000 draws with no error and no all-zero draw

## WASM boundary
- [x] **S1-14** `wasm.rs`: `wasm-bindgen` boundary using `Uint8Array` only; key material never crosses as a JS string
- [x] **S1-15** `init()` with a fail-closed entropy probe (ADR 0007)
- [x] **S1-16** ⭐ **Cross-runtime slice test.** Native-signed verifies in WASM and WASM-signed verifies natively. **This was the stage exit criterion.**

## CI
- [x] **S1-17** CI job `pq-native` (Linux + Windows): fmt, clippy `-D warnings`, build, test
- [x] **S1-18** CI job `pq-wasm`: `wasm-pack build`, headless Chromium, `tsc --build`

> The fallback (`wasm32-wasip1`) was **not needed**; the freestanding build linked.

Prev: [[M1 Stage 0 - Decision follow-through]] · Next: [[M1 Stage 2 - Full algorithm matrix]] · Up: [[Module 1 - PQ Core]]
