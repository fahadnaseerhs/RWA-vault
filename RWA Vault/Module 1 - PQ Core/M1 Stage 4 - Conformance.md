---
tags: [rwa-vault, m1, stage]
stage: 4
status: not-started
---
# M1 Stage 4 — Conformance ⬜

**Goal:** prove standards conformance with NIST ACVP vectors, Falcon Round 3 KATs, differential oracles and golden vectors shared across every runtime. This is the largest stage (18 tasks), parser-heavy but low in conceptual risk.

**Status: 0 / 18**

> Use the **external-interface, empty-context** ACVP groups for ML-DSA and SLH-DSA (from S2-06).

- [ ] **S4-01** `vectors/manifest.json` + `fetch-vectors`: pinned and checksum-verified; no vector bytes committed
- [ ] **S4-02** ACVP parser: ML-DSA keyGen / sigGen / sigVer (only the -44 and -65 groups)
- [ ] **S4-03** ACVP parser: ML-KEM keyGen / encapDecap (-768 and -1024)
- [ ] **S4-04** ACVP parser: SLH-DSA (SHA2-128s)
- [ ] **S4-05** NIST AES-CTR-DRBG, in the **test tree only**
- [ ] **S4-06** Falcon Round 3 KAT parser (`.req` / `.rsp`)
- [ ] **S4-07** Adapter from attached (`sm`) to a detached 666-byte signature, with its own tests
- [ ] **S4-08** PQClean upstream-KAT runner (build-correctness evidence)
- [ ] **S4-09** Differential tests against the `pqcrypto-*` crates: byte-identical output
- [ ] **S4-10** Golden-vector generator writing to `vectors/project/v1/` (frozen on merge)
- [ ] **S4-11** Golden vectors consumed by the Rust tests
- [ ] **S4-12** Golden vectors consumed by the TypeScript tests
- [ ] **S4-13** Golden vectors consumed by the browser/WASM tests
- [ ] **S4-14** Golden vectors consumed by the Foundry tests (Falcon only)
- [ ] **S4-15** Bidirectional cross-runtime suite over all 6 primitives
- [ ] **S4-16** Report emitter (JSON + Markdown) with the ADR 0009 evidence-grade table
- [ ] **S4-17** Zero-case guard: a primitive with 0 executed cases fails the run
- [ ] **S4-18** CI job `pq-conformance`: reports only, never binaries

Prev: [[M1 Stage 3 - Runtime adapters]] · Next: [[M1 Stage 5 - Benchmarks]] · Up: [[Module 1 - PQ Core]]
