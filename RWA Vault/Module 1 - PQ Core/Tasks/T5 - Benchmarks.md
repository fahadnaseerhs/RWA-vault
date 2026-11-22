---
type: task
id: M1-T5
module: M1
stage: 5
status: blocked
agent: coder
assignee: "Fawaz Asif (ASS01 FAW)"
progress: 0/12
depends_on: [M1-T3]
unblocked_by: []
thread: "none yet"
spec: "[[Specs/M1 Task Breakdown]]"
tags: [rwa-vault, m1, task]
updated: 2026-11-22
---
# 📋 T5 — Benchmarks

**In plain words:** reproducible native and browser benchmarks on registered reference environments (ADR 0010). This can run in parallel with Stage 4.

## Blockers
| Blocker | Kind | Owner | Clears when |
|---|---|---|---|
| Stage 3 complete (S3-10, S3-13 remaining, owned by Hassan) | task | ⌨️ Coder (Fawaz for T5) | T3 status is `done` after Researcher VERIFY |

## Subtasks
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

## Acceptance criteria (runnable by a third party)
Logged 2026-11-22 by the Researcher for assignee Fawaz Asif. Parameters come from ADR 0010, which is the source of truth. Benchmarks are measured on the registered environments D1 (CI), D2 (workstation) and A1 (handset). Emulators are not permitted for A1. T5 is `done` only when AC-S5-01 to AC-S5-12 all pass on disk.

- **AC-S5-01 Criterion harness (S5-01, ADR 0010).** `benches/pq_bench.rs` exists. `cargo bench --bench pq_bench -- --list` lists keygen, sign, verify, encaps and decaps for all six primitives. Iterations match ADR 0010: 100 warm-up and 1,000 measured for fast operations; 5 and 50 for SLH-DSA sign and keygen and for Falcon-512 keygen.
- **AC-S5-02 Browser harness (S5-02).** The page under `browser-tests/` runs each operation under `performance.now()` and writes JSON. It loads only over `localhost` or HTTPS.
- **AC-S5-03 Native spec scanner (S5-03, ADR 0010).** Writes CPU model, physical and logical cores, RAM, OS name and build, target triple, `rustc` version and resolved features to JSON. Linux reads `/proc`; Windows uses WMI. Shown by one run on each OS.
- **AC-S5-04 Browser spec scanner (S5-04).** Collects the high-entropy UA-CH values (`model`, `platform`, `platformVersion`, `architecture`, `bitness`, `fullVersionList`), plus `hardwareConcurrency`, `deviceMemory`, screen size and `devicePixelRatio`.
- **AC-S5-05 Missing-model hard error (S5-05).** A mobile user agent with no `model` value, served over plain HTTP, makes the harness exit with a hard error. Shown by a test run with a faked user agent.
- **AC-S5-06 Fingerprint (S5-06, ADR 0010 rule 1).** SHA-256 over CPU model, core count, RAM bucket, OS major version and, for A1, device model. Two fixtures that differ only in browser patch version or OS build give the same fingerprint.
- **AC-S5-07 Registration (S5-07).** `reports/benchmarks/environments.json` starts empty. The first run in a slot writes the scanned spec, the fingerprint, the commit and the date.
- **AC-S5-08 Drift detection (S5-08, ADR 0010 rule 3).** A second run with a changed spec writes `"environment": "unregistered"` and `"comparable": false`, and prints the spec diff. The registered entry is unchanged (file hash compared before and after).
- **AC-S5-09 A1 profile warning (S5-09).** At registration the harness warns if `deviceMemory` is above 8 GB or the core count suggests a flagship. It warns and does not refuse. A human confirms the profile once, and the confirmation is recorded in the report.
- **AC-S5-10 Statistics (S5-10, ADR 0010).** Each report shows median, p95, min and max, each with its iteration count. Checked against a fixture with known durations.
- **AC-S5-11 WASM metrics (S5-11).** Reports raw and gzipped WASM size, instantiation time and peak JS heap.
- **AC-S5-12 Thresholds (S5-12).** (a) Falcon sign p95 under 500 ms on A1, measured by hand and committed. (b) Gzipped package under 2 MB, checked by a script that exits non-zero when exceeded. (c) A D1 regression over 25% fails the release gate. Shown by a synthetic 26% regression giving a non-zero exit.

---

Up: [[M1 Task Board and Todo]] · Hub: [[Module 1 - PQ Core]] · Thread: none yet · Prev: [[T4 - Conformance]] · Next: [[T6 - ETHFALCON dispute verifier]]
