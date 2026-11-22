# ASS01 FAW: Module 1 Assignment for Fawaz Asif

Assignee: Fawaz Asif
Assigned by: Fahad Naseer, Researcher for Module 1
Date: 22 November 2026
Task: M1-T5, Stage 5 (Benchmarks)
Vault notes: RWA Vault/Module 1 - PQ Core/

## 1. What Module 1 Is

RWA-Vault (QORA) tokenises physical gold into on-chain assets. Each gold lot is backed by an attested reserve, and the attestation must stay secure after quantum computers exist. Module 1, PQ Core, supplies the post-quantum cryptography that makes this possible.

PQ Core is one Rust crate. It runs in two places. Natively, it is compiled as a Node.js addon for the backend services. In the browser, it is compiled to WebAssembly (WASM) for the investor and provider front ends. Both builds are wrapped by one TypeScript API, so a signature made on the server must verify in the browser, and the reverse must also hold.

Module 1 uses six primitives, locked by ADR 0002. The signature algorithms are Falcon-padded-512, ML-DSA-44, ML-DSA-65 and SLH-DSA-SHA2-128s. The key encapsulation algorithms are ML-KEM-768 and ML-KEM-1024.

Module 1 is complete when the conformance vectors pass in both the native and WASM builds, and when the gas report for the Falcon dispute verifier is published. Module 2 cannot begin full implementation until Module 1 is released. Stages 0 to 2 are complete, and Stage 3 is being finished by Hassan Attique.

## 2. Your Task: Stage 5, Benchmarks (T5)

### 2.1 Purpose

Stage 5 measures what each primitive costs. It records key generation, signing, verification, encapsulation and decapsulation latency, together with key and signature sizes. The measurements answer research question RQ1 and provide the envelope sizes that Module 2 depends on. A number is useful to the thesis only when it can be reproduced, so every measurement must record the machine it came from.

### 2.2 Position in the Plan

Stage 5 runs in parallel with Stage 4, which Hassan Attique owns. Stage 5 depends on Stage 3. The task is blocked until Fahad verifies Stage 3 (task T3). The board is in RWA Vault/Module 1 - PQ Core/Tasks/M1 Task Board and Todo.md.

### 2.3 Subtasks

**S5-01, Criterion harness.** Write `benches/pq_bench.rs` using the criterion crate. It measures keygen, sign, verify, encapsulate and decapsulate for all six primitives. Warm-up and iteration counts follow ADR 0010 and must not vary between runs.

**S5-02, Browser harness.** Write the browser benchmark harness. It runs each operation between two `performance.now()` readings. It is served from `localhost` or over HTTPS and is placed in `packages/pq-core/browser-tests/`.

**S5-03, Native spec scanner.** Record the machine specification: CPU model, physical and logical cores, total RAM, operating system name and build, target triple, `rustc` version, and the enabled Cargo features. On Linux, read `/proc`. On Windows, use WMI.

**S5-04, Browser spec scanner.** Record the browser's machine specification. Collect the high-entropy user-agent hints (`model`, `platform`, `platformVersion`, `architecture`, `bitness`, `fullVersionList`), together with `hardwareConcurrency`, `deviceMemory`, the screen dimensions and `devicePixelRatio`.

**S5-05, Mobile guard.** If a mobile user agent yields no `model` value, which happens over plain HTTP, the harness must stop with an error. It must not continue with partial data.

**S5-06, Fingerprint.** Compute a SHA-256 hash over the fields that do not change between reboots: CPU model, core count, RAM bucket, operating system major version and, for the handset, the device model. Volatile fields, such as the browser patch version and the OS build number, are recorded in the report but excluded from the hash.

**S5-07, Registration.** The file `reports/benchmarks/environments.json` starts empty. The first run in a slot writes the scanned specification, the fingerprint, the commit and the date.

**S5-08, Drift detection.** A later run whose fingerprint differs from the registered one is written with `"environment": "unregistered"` and `"comparable": false`. The harness prints the difference between the two specifications. It never overwrites the registered entry.

**S5-09, Handset profile warning.** At registration, the harness warns if `deviceMemory` exceeds 8 GB or if the core count suggests a flagship device. The warning does not stop the run. A person confirms the profile once, and the confirmation is recorded.

**S5-10, Statistics.** Each report states the median, the 95th percentile, the minimum and the maximum. Each statistic is shown with the number of iterations it was computed from.

**S5-11, WASM metrics.** Report the raw and gzipped size of the WASM module, the instantiation time and the peak JavaScript heap.

**S5-12, Thresholds.** Three conditions apply. Falcon-512 signing must have a 95th percentile under 500 ms on the handset (A1). The gzipped package must be under 2 MB. A regression of more than 25% on the reproducible desktop reference (D1) fails the release gate.

### 2.4 Measurement Protocol

These values come from ADR 0010 and must not be changed in code without a superseding ADR.

- Build: release, optimised, with the `kat` feature absent (ADR 0007).
- Fast operations (Falcon-512, ML-DSA and ML-KEM keygen, sign, verify, encapsulate and decapsulate): 100 warm-up and 1,000 measured iterations.
- SLH-DSA-SHA2-128s signing and key generation, and Falcon-512 key generation: 5 warm-up and 50 measured iterations.
- Test payload: a fixed 256-byte message.
- Sizes are read once from `metadata()` and checked against the ADR 0006 table. They are not measured again on each environment.

### 2.5 Environments

| Slot | Machine | Who runs it | Where the report is kept |
|---|---|---|---|
| D1 | GitHub-hosted `ubuntu-24.04` runner (CI job `pq-native`) | CI, on every commit | CI artefact; used for regression checks |
| D2 | One team workstation, fixed for the project | By hand, at each milestone gate | Committed under `reports/benchmarks/` |
| A1 | One physical mid-range Android handset: released within four years, Snapdragon 6-series or Dimensity 700-series class, 4 to 8 GB RAM, Chrome for Android | By hand, at each milestone gate | Committed under `reports/benchmarks/` |

Emulators are not permitted for A1. Before the first registration, Fahad must confirm which workstation is D2 and which handset is A1.

## 3. Acceptance Criteria

Every criterion runs from `packages/pq-core` on a clean checkout. Fahad, as Researcher, runs each one and records the output. Task T5 is done only when all twelve criteria pass on disk.

**AC-S5-01 Criterion harness.** `benches/pq_bench.rs` exists. The command `cargo bench --bench pq_bench -- --list` lists keygen, sign, verify, encapsulate and decapsulate for all six primitives. The iteration counts match section 2.4.

**AC-S5-02 Browser harness.** The page in `browser-tests/` runs each operation under `performance.now()` and writes JSON. It loads only from `localhost` or HTTPS.

**AC-S5-03 Native scanner.** The scanner writes CPU model, cores, RAM, operating system, target triple, `rustc` version and features to JSON. One run is shown on Linux and one on Windows.

**AC-S5-04 Browser scanner.** The scanner collects every field listed in S5-04.

**AC-S5-05 Mobile guard.** A mobile user agent without `model`, served over plain HTTP, makes the harness exit with an error. This is shown by a test run with a faked user agent.

**AC-S5-06 Fingerprint.** Two fixtures that differ only in browser patch version or OS build produce the same fingerprint.

**AC-S5-07 Registration.** `environments.json` is empty before the first run. After the first run, the slot contains the specification, the fingerprint, the commit and the date.

**AC-S5-08 Drift.** A second run with a changed specification writes `"environment": "unregistered"` and `"comparable": false`, and prints the difference. The hash of the registered entry is the same before and after the run.

**AC-S5-09 Handset warning.** The warning appears when `deviceMemory` exceeds 8 GB, and the run continues.

**AC-S5-10 Statistics.** A fixture with known durations produces the expected median, 95th percentile, minimum and maximum, each shown with its iteration count.

**AC-S5-11 WASM metrics.** The report contains raw size, gzipped size, instantiation time and peak JavaScript heap.

**AC-S5-12 Thresholds.** (a) The Falcon-512 signing 95th percentile is under 500 ms on A1, measured by hand and committed. (b) A script exits with an error when the gzipped package exceeds 2 MB. (c) A synthetic 26% regression on D1 causes the release gate to exit with an error.

## 4. Coding Guidance

### 4.1 Setup

Install the toolchains before you begin. Rust 1.81.0 is required on every machine that builds this package, and the `wasm32-unknown-unknown` target must be added. The repository's `CONTRIBUTING.md` describes two setup paths: a Dev Container, which is recommended, or a local installation.

```powershell
rustup target add wasm32-unknown-unknown
cargo install wasm-pack --locked
pnpm install
```

### 4.2 Build and Run Commands

Run these from the repository root unless a different directory is stated.

```powershell
cargo build --release --manifest-path packages/pq-core/native/Cargo.toml
pnpm --filter @rwa-vault/pq-core build:addon
pnpm --filter @rwa-vault/pq-core build:wasm
cargo bench --manifest-path packages/pq-core/native/Cargo.toml --bench pq_bench -- --list
cargo bench --manifest-path packages/pq-core/native/Cargo.toml --bench pq_bench
```

The browser harness is run with `node packages/pq-core/browser-tests/run.mjs`, after the WASM package has been built.

### 4.3 Where Code Goes

| Item | Location |
|---|---|
| Criterion harness (S5-01) | `packages/pq-core/native/benches/pq_bench.rs` |
| Browser harness and scanner (S5-02, S5-04, S5-05) | `packages/pq-core/browser-tests/` |
| Native scanner (S5-03) | `packages/pq-core/native/benches/` or a helper module, to be confirmed with the Researcher |
| Fingerprint and registration (S5-06 to S5-09) | Node script in `packages/pq-core/scripts/`, to be confirmed with the Researcher |
| Reports and registration file | `packages/pq-core/reports/benchmarks/` |

If you need a crate or package that is not yet listed in `Cargo.toml` or `package.json`, ask in the thread first and record the choice as a decision (section 6). Every new dependency must be pinned in the lockfile.

### 4.4 Rules for the Code

- Use the release profile for every measurement. Never report a debug build as a result.
- Do not change the warm-up or iteration counts in a run. They are constants set by ADR 0010.
- Do not put secret key material in a report, a log or an error message. Error messages must not contain byte data.
- Do not add `Debug` or `Clone` to any type that holds secret material. The existing secret wrappers enforce this.
- In tests, assert the specific expected value or error variant. Do not assert only that a call failed.
- Keep the scanners free of hand-typed values. Every environment field is read from the machine.
- Write the fixtures for S5-06 to S5-10 before the code that uses them, so that each acceptance criterion has a test that can fail.

### 4.5 Working Through the Subtasks

Start with S5-01 and S5-03, because they produce the first numbers. Next, do S5-06 and S5-07, which can be tested with fixtures before any hardware is measured. Then do S5-02, S5-04 and S5-05, which need a browser. Do S5-08 to S5-11 next, and do S5-12 last, because its thresholds are checked against real reports.

Before you start any subtask that calls the adapters, confirm that Task T3 has been verified. You may start the scanners, which do not call the adapters, earlier only after Fahad agrees in the thread.

## 5. Branches, Commits and Pull Requests

### 5.1 Which Branch to Start From

Start from `feat/finance-modules`. This is the only branch that contains all of the Module 1 material: the Stage 1 to Stage 3 code in `packages/pq-core`, the Module 1 vault notes, the task notes and the assignment documents. The branch `main` does not contain any of this yet, so do not start from `main`. The branch `codex/module-1` contains the same `packages/pq-core` code, but it lacks the vault, the assignments and the Module 3 work, so do not use it.

Fahad will merge `feat/finance-modules` into `main` after he has verified the work. Until then, `feat/finance-modules` is the base for everything in this assignment.

### 5.2 Steps

1. Get the current branch from GitHub:

```powershell
git fetch origin
git checkout feat/finance-modules
git pull origin feat/finance-modules
```

2. Create your working branch from `feat/finance-modules`:

```powershell
git checkout -b feat/m1-fawaz-s5
```

3. Commit each subtask separately, using a message that names the subtask. For example:

```powershell
git add packages/pq-core/native/benches/pq_bench.rs
git commit -m "feat(m1): S5-01 criterion harness for six primitives"
```

Write commit messages in the imperative mood. Do not commit `target/`, `node_modules/`, `dist/`, `pkg/` or any raw log that contains secrets. Do not commit raw logs that contain secrets or identifiers beyond the scanned specification.

4. Push the branch:

```powershell
git push -u origin feat/m1-fawaz-s5
```

5. Open a pull request on GitHub with the base branch set to `feat/finance-modules`, not `main`. The title should name the task, for example "M1-T5 Benchmarks (S5-01 to S5-12)". In the description, list each subtask, its acceptance criterion and the command that proves it.

6. The team requires two approvals before a pull request is merged. Only Fahad merges. Do not merge your own pull request, and do not merge a pull request that has fewer than two approvals.

7. Keep the vault notes in the same pull request as the code they describe, so that the task notes, the thread and the code stay consistent.

## 6. Decisions and ADRs

Some decisions cannot be made without Fahad. Raise them before you implement the affected code.

- **Test-scope decisions** need a Question note in `RWA Vault/Module 1 - PQ Core/Questions/` and a row in `Decisions/Decisions Log.md`. The next number is Q03. Use the template in `RWA Vault/_Templates/Template - Decision.md`.
- **Measurement-protocol decisions** change ADR 0010, which is Accepted. They need a new ADR that supersedes it. Examples include the fingerprint fields, the RAM bucket size and the regression baseline in S5-12.
- **Environment decisions**, such as the choice of D2 and A1 or any re-registration, need an ADR, because ADR 0010 requires one.

To claim an ADR number, first commit a stub file `docs/adr/00NN-slug.md` containing `Status: Reserved`. The next free number is 0032 as of 22 November 2026. Check the directory again before you claim it, because another team member may claim it first. Never renumber or reuse a number.

Record every decision in the thread using the message format in `RWA Vault/Agents/Protocol.md`, and add a line to the Changelog.

## 7. Done Rule and Review

A subtask is ticked when its work is written and its output is posted in the thread. A task is done only when Fahad runs every acceptance criterion on disk and records a `VERIFY ✅` entry. Passing compilation or passing tests is not sufficient by itself. A measurement counts only when it is in a committed report with its environment identity. A number shown in chat or in a presentation does not count.

If a criterion fails, post a report in the thread. Do not change the criterion yourself. If a criterion appears to be wrong, post a question in the thread and wait for the answer.
