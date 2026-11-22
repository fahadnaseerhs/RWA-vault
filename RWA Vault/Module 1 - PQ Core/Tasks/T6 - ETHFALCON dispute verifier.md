---
type: task
id: M1-T6
module: M1
stage: 6
status: blocked
agent: coder
progress: 0/10
depends_on: [M1-T4]
unblocked_by: []
thread: "none yet"
spec: "[[Specs/M1 Task Breakdown]]"
tags: [rwa-vault, m1, task]
updated: 2026-11-22
---
# 📋 T6 — ETHFALCON dispute verifier

**In plain words:** an on-chain Falcon verifier (ETHFALCON, pinned per ADR 0011) for disputes only, plus gas measurements for the RQ3 report.

## Blockers
| Blocker | Kind | Owner | Clears when |
|---|---|---|---|
| S4-14 (conformance vectors) | task | Coder | T4 status is `done` after Researcher VERIFY |

## Subtasks
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

## Acceptance criteria (runnable by a third party)
> _Not written yet. The Researcher writes these as a `PLAN` entry in the thread before the Coder starts. Without them no `VERIFY ✅` is possible, so this task cannot reach `done`._

---

Up: [[M1 Task Board and Todo]] · Hub: [[Module 1 - PQ Core]] · Thread: none yet · Prev: [[T5 - Benchmarks]] · Next: [[T7 - Release gate]]
