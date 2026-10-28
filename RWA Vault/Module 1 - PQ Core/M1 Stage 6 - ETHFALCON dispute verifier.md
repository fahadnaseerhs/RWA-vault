---
tags: [rwa-vault, m1, stage]
stage: 6
status: not-started
---
# M1 Stage 6 — ETHFALCON dispute verifier ⬜

**Goal:** an on-chain Falcon verifier (ETHFALCON, pinned per ADR 0011) for disputes only, plus gas measurements for the RQ3 report.

**Status: 0 / 10**

- [ ] **S6-01** Vendor ETHFALCON at `7d5ecd41…` into `contracts/lib/ethfalcon/` with PROVENANCE and the MIT licence
- [ ] **S6-02** Rust adapter `falcon_to_evm(pk, sig) → (salt, s2_coefficients, pk_ntt)`
- [ ] **S6-03** TS/script path from a golden vector to verifier calldata
- [ ] **S6-04** Foundry positive tests (ADR 0009 Sources B + E)
- [ ] **S6-05** Negative tests: flipped signature, flipped message, wrong key
- [ ] **S6-06** Malformed and boundary tests; no generic panics
- [ ] **S6-07** Gas measurement: deployment and per-verification, reported separately
- [ ] **S6-08** `forge snapshot` gas-regression threshold in CI
- [ ] **S6-09** Verify that `evm_version` (`cancun`) works on Arbitrum Sepolia; if not, drop to `shanghai` and record it
- [ ] **S6-10** RQ3 report: gas figures, the dispute-only policy, δ-sensitivity, and the "unaudited" warning

Prev: [[M1 Stage 5 - Benchmarks]] · Next: [[M1 Stage 7 - Release gate]] · Up: [[Module 1 - PQ Core]]
