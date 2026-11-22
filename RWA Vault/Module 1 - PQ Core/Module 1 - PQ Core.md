---
type: hub
module: M1
phase: 1
sprint: 1–2
status: in-progress
depends_on: [M0 - Foundation & Devnet]
blocks: [Module 2 - PQ-PKI & Envelope]
tags: [rwa-vault, module, hub]
updated: 2026-11-22
---
# Module 1 — PQ Core

**What it is:** one Rust crate that runs natively (Node addon) and in the browser (WASM), with a TypeScript API on top. · **Done when:** all CAVP vectors pass in both the native and WASM builds, and the gas report for the Falcon dispute verifier is published.

- **Depends on:** [[M0 - Foundation & Devnet]] · **Blocks:** [[Module 2 - PQ-PKI & Envelope]]
- **Dashboard:** [[00 M1 Dashboard]] · **Board:** [[Tasks/M1 Task Board and Todo]]
- **Decisions:** [[Decisions/Open Questions for Fahad]] · [[Decisions/Decisions Log]]
- **Understand it:** [[Understanding/00 - What is PQ Core]] → [[Understanding/01 - Why Post-Quantum]] → [[Understanding/02 - The Six Primitives]] → [[Understanding/03 - Architecture]] → [[Understanding/04 - What's Been Built]] → [[Understanding/05 - What Remains]]
- **Run it:** [[Running/01 - Build Commands]] · [[Running/02 - Test Commands]] · [[Running/03 - pqctl Usage]]
- **Package:** `packages/pq-core` (Rust in `native/`, TypeScript in `src/`) · **Build plan source:** `docs/reports/M1-task-breakdown.md` (see [[Specs/M1 Task Breakdown]])

---

## Primitive inventory (six — locked by ADR 0002)
- Signatures: **Falcon-padded-512**, **ML-DSA-44**, **ML-DSA-65**, **SLH-DSA-SHA2-128s**
- KEMs: **ML-KEM-768**, **ML-KEM-1024**

## Locked invariants (carry-forward for every M1 task)
- **ACVP groups:** ML-DSA and SLH-DSA use the FIPS *external interface* with an **empty context** and no prehash, so select those groups. Falcon uses Round 3 KATs (ADR 0009). Source: [[Tasks/T2 - Full algorithm matrix|T2 · S2-06]].
- **Secret wrappers** have **no `Debug` / `Clone`**, enforced by `compile_fail` doctests ([[Tasks/T1 - Crate skeleton and Falcon slice|T1]]).
- **KAT gating:** the `kat` feature is refused in optimised builds; `scripts/verify-no-kat-symbols.py` checks the artefacts ([[Tasks/T7 - Release gate|T7]]).
- **Assertions:** tests assert exact `PqError` variants, never a bare `is_err()`.

## Tasks & stages
Each stage is one Task note (`Tasks/`). Status and subtask ticks live only in those notes. Order: T0 → T1 → T2 → T3; after T3, T4 and T5 run in parallel; T6 needs S4-14; T7 is last.

Prev: [[M0 - Foundation & Devnet]] · Next: [[Module 2 - PQ-PKI & Envelope]] · Up: [[All Modules]]
Related: [[ADR Index]], [[Project Memory]], [[Changelog]]
