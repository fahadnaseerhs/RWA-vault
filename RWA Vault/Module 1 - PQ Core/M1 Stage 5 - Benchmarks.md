---
tags: [rwa-vault, m1, stage]
stage: 5
status: not-started
---
# M1 Stage 5 — Benchmarks ⬜

**Goal:** reproducible native and browser benchmarks on registered reference environments (ADR 0010). This can run in parallel with Stage 4.

**Status: 0 / 12**

- [ ] **S5-01** `benches/pq_bench.rs`: criterion harness with the ADR 0010 warm-up and iteration counts
- [ ] **S5-02** Browser benchmark harness (`performance.now()`)
- [ ] **S5-03** Native spec scanner (CPU, RAM, OS, target, `rustc`)
- [ ] **S5-04** Browser spec scanner (UA-CH hints, cores, memory, screen)
- [ ] **S5-05** Hard error on a missing `model` for mobile user agents (non-HTTPS guard)
- [ ] **S5-06** Fingerprint: SHA-256 over non-volatile fields only
- [ ] **S5-07** Register `environments.json` on first run
- [ ] **S5-08** Drift detection: mark the run `unregistered` / `comparable: false` and print the spec diff
- [ ] **S5-09** A1 profile warning at registration
- [ ] **S5-10** Report: median, p95, min and max, each shown with its iteration count
- [ ] **S5-11** WASM size (raw and gzipped), instantiation time, peak JS heap
- [ ] **S5-12** Thresholds: Falcon sign p95 < 500 ms on A1; gzipped package < 2 MB; a D1 regression over 25% fails the release gate

Prev: [[M1 Stage 4 - Conformance]] · Next: [[M1 Stage 6 - ETHFALCON dispute verifier]] · Up: [[Module 1 - PQ Core]]
