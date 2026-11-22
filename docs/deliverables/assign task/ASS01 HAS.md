# ASS01 HAS: Module 1 Assignment for Hassan Attique

Assignee: Hassan Attique
Assigned by: Fahad Naseer, Researcher for Module 1
Date: 22 November 2026
Tasks: M1-T3 remainder (S3-10, S3-13) and M1-T4, Stage 4 (Conformance)
Vault notes: RWA Vault/Module 1 - PQ Core/

## 1. What Module 1 Is

RWA-Vault (QORA) tokenises physical gold into on-chain assets. Each gold lot is backed by an attested reserve, and the attestation must stay secure after quantum computers exist. Module 1, PQ Core, supplies the post-quantum cryptography that makes this possible.

PQ Core is one Rust crate. It runs in two places. Natively, it is compiled as a Node.js addon for the backend services. In the browser, it is compiled to WebAssembly (WASM) for the investor and provider front ends. Both builds are wrapped by one TypeScript API, so a signature made on the server must verify in the browser, and the reverse must also hold.

Module 1 uses six primitives, locked by ADR 0002. The signature algorithms are Falcon-padded-512, ML-DSA-44, ML-DSA-65 and SLH-DSA-SHA2-128s. The key encapsulation algorithms are ML-KEM-768 and ML-KEM-1024.

Module 1 is complete when the conformance vectors pass in both the native and WASM builds, and when the gas report for the Falcon dispute verifier is published. Module 2 cannot begin full implementation until Module 1 is released. Stages 0 to 2 are complete, and most of Stage 3 is complete.

## 2. Your Tasks

### 2.1 Stage 3 Remainder (T3, Runtime Adapters)

Stage 3 connects the Rust code to the TypeScript layer. Most of it is finished. Two subtasks remain.

**S3-10, Contract-equivalence test.** Write `packages/pq-core/src/__tests__/contract.test.ts`. One test suite loads both the native adapter and the WASM adapter in Node, and runs the same checks against each. The checks cover key lengths, cross-verification in both directions, shared secrets from encapsulation, and identical error codes for malformed input. The test runs in Node only, as decided in Q02.

**S3-13, Test script.** Replace the placeholder `"no tests yet"` with a real `pnpm test` that runs the S3-10 file. The script is already pointed at `dist/__tests__/contract.test.js`.

Subtask S3-05, prebuilt addon binaries for CI, is descoped from MS1 by decision Q01. You do no work on it. Rust is required on every machine instead.

### 2.2 Stage 4, Conformance (T4)

Stage 4 proves that the implementations produce the same outputs as the reference implementations, using the official test vectors. It is the largest stage, with eighteen subtasks. Stage 4 starts after Fahad verifies Stage 3.

The subtasks are grouped as follows.

- **Vector sources (S4-01).** Create `vectors/manifest.json` and a `fetch-vectors` script. The vectors are fetched from pinned NIST ACVP and Falcon Round 3 sources, and checked against SHA-256 hashes. Vector bytes are never committed, with one exception: the project golden vectors in `vectors/project/v1/`.
- **ACVP parsers (S4-02 to S4-04).** Parse the NIST ACVP vector files for ML-DSA-44 and ML-DSA-65, for ML-KEM-768 and ML-KEM-1024, and for SLH-DSA-SHA2-128s. Only the parameter sets listed in ADR 0002 are used. SLH-DSA signing is run in the Rust test harness only, never in the addon.
- **Test DRBG (S4-05).** Add the NIST AES-CTR-DRBG, which the Falcon KAT files require. It lives in the test tree only, as ADR 0007 requires.
- **Falcon KAT (S4-06 to S4-08).** Parse the Falcon Round 3 `.req` and `.rsp` files. Convert the attached signature format into the 666-byte detached form used by M1 (S4-07). Run the PQClean upstream KAT files as a build-correctness check (S4-08).
- **Differential tests (S4-09).** Confirm that the vendored build and the `pqcrypto-*` crates produce byte-identical output for every vector.
- **Golden vectors (S4-10 to S4-14).** Write a generator that writes `vectors/project/v1/`. It must be deterministic. Rust, TypeScript, WASM and Foundry each consume these vectors. S4-14, the Foundry Falcon suite, unblocks Stage 6, so it should be completed early.
- **Cross-runtime suite and reporting (S4-15 to S4-18).** Check that signatures from the native build verify in WASM and the reverse, for all six primitives. Write the report emitter, which produces JSON and Markdown with the ADR 0009 evidence table. Add a zero-case guard, so that a primitive with no executed cases fails the run. Add the CI job `pq-conformance`, which uploads reports only and never binaries.

Two points from ADR 0009 must be respected in every report. Falcon-512 has no CAVP or ACVP vectors, so its conformance grade is "KAT only". Running ACVP vectors is not a NIST validation, so no certification is claimed.

## 3. Acceptance Criteria

### 3.1 Stage 3 Remainder

**AC-09, Contract equivalence.** The file `src/__tests__/contract.test.ts` exists and loads both `createNativeAdapter()` and `createWasmAdapter()` in Node. For every algorithm in `PQ_ALGORITHMS`, it checks that key lengths match the metadata, that signatures cross-verify in both directions, that encapsulated secrets match, and that malformed inputs give the same error code from both adapters.

**AC-10, Test script.** `pnpm test` exits with code 0, runs at least the AC-09 cases, reports no skipped tests, and the placeholder text is gone from the repository.

The Stage 3 criteria AC-01 to AC-13 are recorded in RWA Vault/Module 1 - PQ Core/Threads/Thread - T3 Runtime adapters.md. All thirteen must pass for T3 to be verified.

### 3.2 Stage 4

Every criterion runs from `packages/pq-core` on a clean checkout. Fahad runs each one and records the output. Task T4 is done only when all eighteen criteria pass on disk.

**AC-S4-01 Vectors fetched.** `vectors/manifest.json` lists Sources A, B, C and D, each with its URL, pinned tag or commit, file list and SHA-256. `fetch-vectors` exits with code 0 on a fresh fetch. After one byte of a fetched copy is changed, it exits with an error. `git ls-files vectors` shows no `.json`, `.req` or `.rsp` file under the A, B or C paths. Only `vectors/project/v1/` is committed.

**AC-S4-02 ML-DSA parser.** The parser runs the ML-DSA-44 and ML-DSA-65 groups of keyGen, sigGen and sigVer, using the external interface with an empty context and no prehash. Its output gives pass, fail and skip counts for each group.

**AC-S4-03 ML-KEM parser.** The parser runs ML-KEM-768 and ML-KEM-1024 keyGen and encapDecap. Its output gives pass, fail and skip counts.

**AC-S4-04 SLH-DSA parser.** The parser runs SLH-DSA-SHA2-128s keyGen, sigGen and sigVer. The sigGen step runs in the Rust test harness and not in the addon.

**AC-S4-05 DRBG isolation.** A search of `native/src` and `src` for `ctr_drbg` or `AesCtrDrbg` returns nothing. The release dependency tree contains no DRBG crate.

**AC-S4-06 Falcon KAT parser.** The parser reads `falcon512-KAT.req` and `falcon512-KAT.rsp` and runs every entry. The number of executed entries equals the number of `count =` lines in the `.rsp` file.

**AC-S4-07 Signature adapter.** For every KAT entry, the 666-byte detached signature equals the signature extracted from the attached `sm` form. A wrong-length input is rejected. The adapter has its own tests.

**AC-S4-08 Upstream KAT runner.** The runner executes the vendored `.rsp` fixtures. Its results are reported under Source C as a build-correctness check, not as standards conformance.

**AC-S4-09 Differential oracle.** For every Source A, B and C case, the vendored build and the `pqcrypto-*` crates give byte-identical output. Any mismatch fails the run.

**AC-S4-10 Golden-vector generator.** The generator writes `vectors/project/v1/`. Two runs produce no difference. A checksum manifest is committed, and the file list is fixed on merge.

**AC-S4-11 Rust consumes golden vectors.** The Rust test suite checks every case in `vectors/project/v1/`. Its case count equals the generator's count.

**AC-S4-12 TypeScript consumes golden vectors.** The TypeScript suite checks every case. Its case count equals the generator's count.

**AC-S4-13 WASM consumes golden vectors.** The browser or WASM suite checks every case. Its case count equals the generator's count.

**AC-S4-14 Foundry consumes Falcon vectors.** The Foundry suite checks every Falcon case. This criterion must pass before Stage 6 starts.

**AC-S4-15 Cross-runtime suite.** For all six primitives, over Sources A, B and E, signatures from the native build verify in WASM, and signatures from WASM verify in the native build.

**AC-S4-16 Report emitter.** The emitter writes `reports/conformance/report.json` and `report.md`. The Markdown contains the ADR 0009 evidence table exactly as written. Falcon-512 is shown as "KAT only, no CAVP exists".

**AC-S4-17 Zero-case guard.** A run in which any primitive executes zero cases exits with an error. This is shown by running the suite against an empty fixture set.

**AC-S4-18 CI job.** The job `pq-conformance` runs on `ubuntu-24.04` and uploads only the report. A search of the workflow file finds no upload of a `.node` or `.wasm` file. The job passes on a pull request.

## 4. Coding Guidance

### 4.1 Setup

Install the toolchains before you begin. Rust 1.81.0 is required on every machine that builds this package, and the `wasm32-unknown-unknown` target must be added. The repository's `CONTRIBUTING.md` describes two setup paths, a Dev Container or a local installation.

```powershell
rustup target add wasm32-unknown-unknown
cargo install wasm-pack --locked
pnpm install
```

### 4.2 Build and Test Commands

Run these from the repository root.

```powershell
pnpm --filter @rwa-vault/pq-core build:addon
pnpm --filter @rwa-vault/pq-core build:wasm
pnpm --filter @rwa-vault/pq-core build
pnpm --filter @rwa-vault/pq-core test
pnpm --filter @rwa-vault/pq-core lint
pnpm --filter @rwa-vault/pq-core test:rust
```

The first build of the addon produces `packages/pq-core/pq-core.node`. Without it, the native adapter cannot load.

### 4.3 Where Code Goes

| Item | Location |
|---|---|
| Contract test (S3-10) | `packages/pq-core/src/__tests__/contract.test.ts` |
| Vector manifest and fetch script (S4-01) | `packages/pq-core/vectors/` |
| ACVP parsers (S4-02 to S4-04) | `packages/pq-core/native/tests/` |
| Falcon KAT parser and adapter (S4-06, S4-07) | `packages/pq-core/native/tests/` |
| Golden-vector generator (S4-10) | `packages/pq-core/scripts/`, to be confirmed with the Researcher |
| Golden vectors (committed) | `packages/pq-core/vectors/project/v1/` |
| Reports | `packages/pq-core/reports/conformance/` |

Shared fixtures are read by both the Rust and the TypeScript tests. Do not copy a fixture into a second place. The shared error-code fixture is `packages/pq-core/native/tests/vectors/error-codes.json` (AC-03).

If you need a dependency that is not yet listed in `Cargo.toml` or `package.json`, ask in the thread first and record the choice as a decision (section 6). Commit the updated lockfile with the change.

### 4.4 Rules for the Code

- Use exact error variants in tests. Do not assert only that a call returned an error.
- Error messages must not contain byte data. Each addon error has the form `[CODE] text`, where the code is one of the nine stable codes.
- Do not add `Debug` or `Clone` to any type that holds secret material.
- The DRBG and any other test-only code must not be compiled into release builds.
- Do not use `any` in the TypeScript code.
- Do not commit vector bytes from Sources A, B or C.
- Keep each parser separate from the test that uses it, so that a failure can be traced to one place.

### 4.5 Working Through the Subtasks

Begin with S3-10 and S3-13, because Stage 4 depends on Stage 3 being verified. Then do S4-01 to fetch and pin the vectors, and S4-06 for the Falcon KAT parser, which can start before Stage 3 is verified because it does not call the adapters. Do S4-02 to S4-05 next, then S4-07 to S4-09. Do S4-10 to S4-14 after the parsers are complete, and do S4-14 early, because Stage 6 depends on it. Finish with S4-15 to S4-18.

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
git checkout -b feat/m1-hassan-s3-s4
```

3. Commit each subtask separately, using a message that names the subtask. For example:

```powershell
git add packages/pq-core/src/__tests__/contract.test.ts
git commit -m "test(m1): S3-10 contract-equivalence suite for both adapters"
```

Write commit messages in the imperative mood. Do not commit `target/`, `node_modules/`, `dist/`, `pkg/` or any raw log that contains secrets. 

4. Push the branch:

```powershell
git push -u origin feat/m1-hassan-s3-s4
```

5. Open a pull request on GitHub with the base branch set to `feat/finance-modules`, not `main`. The title should name the task, for example "M1-T3 remainder and M1-T4 Conformance". In the description, list each subtask, its acceptance criterion and the command that proves it.

6. The team requires two approvals before a pull request is merged. Only Fahad merges. Do not merge your own pull request, and do not merge a pull request that has fewer than two approvals.

7. Keep the vault notes in the same pull request as the code they describe, so that the task notes, the thread and the code stay consistent.

## 6. Decisions and ADRs

Some decisions cannot be made without Fahad. Raise them before you implement the affected code.

- **Test-scope decisions** need a Question note in `RWA Vault/Module 1 - PQ Core/Questions/` and a row in `Decisions/Decisions Log.md`. The next number is Q03. Use the template in `RWA Vault/_Templates/Template - Decision.md`.
- **Architecture decisions**, such as a change to how vectors are pinned or a change to a byte-level contract, need an ADR as well as a Question note.

To claim an ADR number, first commit a stub file `docs/adr/00NN-slug.md` containing `Status: Reserved`. The next free number is 0032 as of 22 November 2026. Check the directory again before you claim it, because another team member may claim it first. Never renumber or reuse a number.

Record every decision in the thread using the message format in `RWA Vault/Agents/Protocol.md`, and add a line to the Changelog.

## 7. Done Rule and Review

A subtask is ticked when its work is written and its output is posted in the thread. A task is done only when Fahad runs every acceptance criterion on disk and records a `VERIFY ✅` entry. Passing compilation or passing tests is not sufficient by itself.

If a criterion fails, post a report in the thread. Do not change the criterion yourself. If a criterion appears to be wrong, post a question in the thread and wait for the answer.
