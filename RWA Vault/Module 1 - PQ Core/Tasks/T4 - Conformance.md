---
type: task
id: M1-T4
module: M1
stage: 4
status: blocked
agent: coder
assignee: "Hassan Attique (ASS01 HAS)"
progress: 0/18
depends_on: [M1-T3]
unblocked_by: []
thread: "none yet"
spec: "[[Specs/M1 Task Breakdown]]"
tags: [rwa-vault, m1, task]
updated: 2026-11-22
---
# 📋 T4 — Conformance

**In plain words:** prove standards conformance with NIST ACVP vectors, Falcon Round 3 KATs, differential oracles and golden vectors shared across every runtime. This is the largest stage (18 tasks), parser-heavy but low in conceptual risk.

## Blockers
| Blocker | Kind | Owner | Clears when |
|---|---|---|---|
| Stage 3 complete (S3-10, S3-13 remaining, owned by Hassan) | task | ⌨️ Coder (Hassan) | T3 status is `done` after Researcher VERIFY |

## Subtasks
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

## Acceptance criteria (runnable by a third party)
Logged 2026-11-22 by the Researcher for assignee Hassan Attique. Every criterion runs from `packages/pq-core` on a clean checkout. The Researcher runs them and records output in a `VERIFY ✅` entry. T4 is `done` only when AC-S4-01 to AC-S4-18 all pass on disk.

- **AC-S4-01 Vectors fetched, not committed (S4-01, ADR 0009 storage rule).** `vectors/manifest.json` lists Sources A, B, C and D, each with URL, pinned tag or commit, file list and SHA-256. `fetch-vectors` exits 0 on a fresh fetch and exits non-zero after one byte of a fetched file is changed (tested on a copy). `git ls-files vectors` shows no `.json`, `.req` or `.rsp` under the A/B/C paths; only `vectors/project/v1/` is committed.
- **AC-S4-02 ML-DSA parser (S4-02).** Runs the ML-DSA-44 and ML-DSA-65 groups of `keyGen`, `sigGen` and `sigVer` from the `FIPS204` files, using the external interface, empty context, no prehash. Output shows pass, fail and skip counts per group.
- **AC-S4-03 ML-KEM parser (S4-03).** Runs ML-KEM-768 and ML-KEM-1024 `keyGen` and `encapDecap` from the `FIPS203` files. Output shows pass, fail and skip counts.
- **AC-S4-04 SLH-DSA parser (S4-04).** Runs SLH-DSA-SHA2-128s `keyGen`, `sigGen` and `sigVer` from the `FIPS205` files. `sigGen` runs in the Rust test harness only, never in the addon (ADR 0005).
- **AC-S4-05 DRBG in the test tree only (S4-05, ADR 0007).** `grep -rn "ctr_drbg\|AesCtrDrbg" native/src src` returns nothing. The release dependency tree has no DRBG crate.
- **AC-S4-06 Falcon KAT parser (S4-06).** Reads `falcon512-KAT.req` and `falcon512-KAT.rsp` (Round 3) and runs every entry. The executed count equals the number of `count =` lines in the `.rsp`.
- **AC-S4-07 Attached to detached adapter (S4-07).** For every KAT entry, the 666-byte detached signature equals the signature extracted from the attached `sm` form. A wrong-length input is rejected. Own tests exist for this adapter.
- **AC-S4-08 PQClean upstream KAT runner (S4-08).** Runs the vendored `.rsp` fixtures. Results are reported under Source C as a build-correctness check, not as standards conformance (ADR 0009).
- **AC-S4-09 Differential oracle (S4-09).** Every Source A, B and C case gives byte-identical output from the vendored build and the `pqcrypto-*` crates. Any mismatch fails the run.
- **AC-S4-10 Golden-vector generator (S4-10).** Writes `vectors/project/v1/`. Running it twice gives zero diff (deterministic). A checksum manifest is committed, and the file list is frozen on merge.
- **AC-S4-11 Rust consumes golden vectors (S4-11).** The Rust test suite asserts every case in `vectors/project/v1/`. Its case count equals the generator's count.
- **AC-S4-12 TypeScript consumes golden vectors (S4-12).** The TypeScript suite asserts every case. Its case count equals the generator's count.
- **AC-S4-13 WASM consumes golden vectors (S4-13).** The browser or WASM suite asserts every case. Its case count equals the generator's count.
- **AC-S4-14 Foundry consumes Falcon vectors (S4-14).** The Foundry suite asserts every Falcon case. This output unblocks T6.
- **AC-S4-15 Bidirectional cross-runtime suite (S4-15).** For all six primitives over Sources A, B and E: native-signed verifies in WASM, and WASM-signed verifies in native.
- **AC-S4-16 Report emitter (S4-16, ADR 0009).** Writes `reports/conformance/report.json` and `report.md`. The Markdown includes the ADR 0009 evidence-grade table verbatim. Falcon-512 is shown as "KAT only — no CAVP exists".
- **AC-S4-17 Zero-case guard (S4-17).** A run where any primitive executes 0 cases exits non-zero. Shown by running against an empty fixture set.
- **AC-S4-18 CI job `pq-conformance` (S4-18).** Runs on `ubuntu-24.04`. Uploads only the report. A grep of the workflow shows no upload of `*.node` or `*.wasm` files. Green on a PR.

---

Up: [[M1 Task Board and Todo]] · Hub: [[Module 1 - PQ Core]] · Thread: none yet · Prev: [[T3 - Runtime adapters]] · Next: [[T5 - Benchmarks]]
