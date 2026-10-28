---
tags: [rwa-vault, module, m1]
status: in-progress
updated: 2026-09-26
---
# Module 1 — PQ Core

The post-quantum cryptography core: one Rust crate that runs natively (Node addon) and in the browser (WASM), with a TypeScript API on top.

- Package: `packages/pq-core` (Rust in `native/`, TypeScript in `src/`)
- Task source: `docs/reports/M1-task-breakdown.md`
- Manual: `docs/manuals/QORA_Module_1_PQ_Core_Manual.docx`
- Branch: `codex/module-1`

## Primitive inventory (six)
- Signatures: **Falcon-padded-512**, **ML-DSA-44**, **ML-DSA-65**, **SLH-DSA-SHA2-128s**
- KEMs: **ML-KEM-768**, **ML-KEM-1024**

**Depends on:** [[M0 - Foundation & Devnet]] · **Blocks:** [[Module 2 - PQ-PKI & Envelope]]
**Done when (build plan):** all CAVP vectors pass in both the native and WASM builds, and the gas report for the Falcon dispute verifier is published.

## Module tasks (from the build plan) → where they are done
- [x] Rust bindings for Falcon-512, ML-DSA-65, ML-DSA-44, SLH-DSA-SHA2-128s (+ ML-KEM-768/1024) → Stages 1–2 (vendored PQClean replaced liboqs, per ADR 0003)
- [x] WASM browser build (client-side signing; the key never leaves the device) → Stage 1 done, typed adapter in Stage 3 (`src/wasm.ts`, expanded `wasm.rs`)
- [x] Native build for server-side signing (custodian, oracle, admin) → Stage 1 done, Node addon in Stage 3 (`native/napi/`)
- [ ] NIST CAVP/ACVP conformance on native + WASM, all six primitives → Stage 4
- [ ] Benchmarks (latency and sizes, desktop + mid-range Android) → Stage 5
- [ ] ETHFALCON Solidity verifier + gas report (RQ3) → Stage 6

## Stages (subtasks)

| Stage | Note                                             | Tasks | Status             |
| ----- | ------------------------------------------------ | ----- | ------------------ |
| 0     | [[M1 Stage 0 - Decision follow-through]]         | 3     | ✅ Done             |
| 1     | [[M1 Stage 1 - Crate skeleton and Falcon slice]] | 18    | ✅ Done (`afe574c`) |
| 2     | [[M1 Stage 2 - Full algorithm matrix]]           | 17    | ✅ Done (`e13b18a`) |
| 3     | [[M1 Stage 3 - Runtime adapters]]                | 15    | done               |
| 4     | [[M1 Stage 4 - Conformance]]                     | 18    | ⬜ Not started      |
| 5     | [[M1 Stage 5 - Benchmarks]]                      | 12    | ⬜ Not started      |
| 6     | [[M1 Stage 6 - ETHFALCON dispute verifier]]      | 10    | ⬜ Not started      |
| 7     | [[M1 Stage 7 - Release gate]]                    | 9     | ⬜ Not started      |

**Progress: 49 / 102 tasks done (Stages 0–2 complete, Stage 3 in progress 11/15).**

Order: 0 → 1 → 2 → 3. After Stage 3, Stages 4 and 5 can run in parallel. Stage 6 needs S4-14. Stage 7 is last.

## Carry-forward notes
- **Stage 4:** ML-DSA and SLH-DSA use the FIPS *external interface* with an **empty context** and no prehash, so select those ACVP groups. Falcon uses Round 3 KATs (ADR 0009).
- Secret wrappers have **no `Debug`/`Clone`**, enforced by `compile_fail` doctests.
- The `kat` feature is refused in optimised builds; `scripts/verify-no-kat-symbols.py` checks the artefacts.
- Tests assert exact `PqError` variants, never a bare `is_err()`.

## Reference folders

- **[[00 - What is PQ Core|Explainer]]** — What this module is, why it exists, how it works — from intuition to technical detail
- **[[01 - Build Commands|Running]]** — Every command to build, test, and run what's been built so far

Prev: [[M0 - Foundation & Devnet]] · Next: [[Module 2 - PQ-PKI & Envelope]] · Up: [[All Modules]]
Related: [[ADR Index]], [[Project Memory]], [[Changelog]]
