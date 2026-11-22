---
type: task
id: M1-T2
module: M1
stage: 2
status: in-review
agent: coder
progress: 17/17
depends_on: [M1-T1]
unblocked_by: []
thread: "none yet"
spec: "[[Specs/M1 Task Breakdown]]"
commit: e13b18a
tags: [rwa-vault, m1, task]
updated: 2026-11-22
---
# 📋 T2 — Full algorithm matrix

**In plain words:** apply the pattern proven in Stage 1 to the other five primitives. The risk was repetition without attention (a wrong length constant or a sloppy negative test), not new concepts.

## Blockers
| Blocker | Kind | Owner | Clears when |
|---|---|---|---|
| Researcher VERIFY ✅ against acceptance criteria | task | 🧭 Researcher | VERIFY entry in the thread |

## Subtasks
### Primitives
- [x] **S2-01** ML-DSA-44 FFI + wrapper
- [x] **S2-02** ML-DSA-65 FFI + wrapper
- [x] **S2-03** ML-KEM-768 FFI + wrapper (keygen / encaps / decaps; 32-byte shared secret agrees)
- [x] **S2-04** ML-KEM-1024 FFI + wrapper
- [x] **S2-05** SLH-DSA-SHA2-128s via the `slh-dsa` Rust crate, behind the same trait as the C schemes
- [x] **S2-06** Interface finding: ML-DSA and SLH-DSA use the external interface with an empty `ctx` and no prehash. **This decides which ACVP groups Stage 4 selects.**

### Input validation and dispatch
- [x] **S2-07** `algorithms.rs`: dispatch over the 6 IDs; code `0x00` or an unknown code returns `UnsupportedAlgorithm`
- [x] **S2-08** Exact-length checks on every input before any FFI call; ±1 byte returns the right `Malformed*` error
- [x] **S2-09** Algorithm/key mismatch returns `AlgorithmKeyMismatch` before FFI
- [x] **S2-10** 1 MiB message cap: at the cap passes, cap + 1 returns `MessageTooLong`

### Security hygiene
- [x] **S2-11** Secret-buffer sweep: temporaries zeroized, no `Debug`/`Clone` on secrets (enforced by `compile_fail` doctests), no key bytes in panics

### API surface
- [x] **S2-12** Signature API: `keygen` / `sign` / `verify` / `metadata` over the 4 signature IDs
- [x] **S2-13** KEM API: `kem_keygen` / `encapsulate` / `decapsulate` / `kem_metadata`; a KEM ID passed to `sign` is a TS compile error and `UnsupportedAlgorithm` in Rust

### KAT (test-only) hooks
- [x] **S2-14** `kat` feature with a `compile_error!` guard against release builds
- [x] **S2-15** Seed-taking entry points (`keygen_from_seed`, `sign_deterministic`, `encapsulate_with_m`) exist only under `kat`. A symbol dump plus doctests prove they are absent from default builds

### Tests
- [x] **S2-16** Per-algorithm unit tests (round-trip, wrong key, wrong message, empty input) for all 6
- [x] **S2-17** Negative and malformed-input suite `tests/negative_inputs.rs` (ADR 0009 Source F); every case asserts an exact error

## Acceptance criteria (runnable by a third party)
> _Not written yet. The Researcher writes these as a `PLAN` entry in the thread before the Coder starts. Without them no `VERIFY ✅` is possible, so this task cannot reach `done`._

---

Up: [[M1 Task Board and Todo]] · Hub: [[Module 1 - PQ Core]] · Thread: none yet · Prev: [[T1 - Crate skeleton and Falcon slice]] · Next: [[T3 - Runtime adapters]]
