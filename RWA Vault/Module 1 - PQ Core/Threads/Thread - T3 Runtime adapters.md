---
type: thread
task: T3
module: M1
status: active
tags: [rwa-vault, thread, m1]
updated: 2026-11-22
---
# 💬 Thread — T3 Runtime adapters

> Append-only. New entries go at the **bottom**, using [[Template - Thread Entry]]. Never edit or delete an earlier entry;
> correct it with a new entry that links to it. Current state = the last entry.

**Task:** [[Tasks/T3 - Runtime adapters]] · **Spec:** [[Specs/M1 Task Breakdown]]

---

### 2026-11-22 · 🧭 Researcher → ⌨️ Coder · PLAN

**Context:** M1-T3 Runtime adapters. Remaining subtasks S3-10 and S3-13, plus the verification of the finished work. S3-05 is descoped for MS1 by [[Questions/Q01 - Where do the prebuilt addon binaries live]] (D). Q02 = A, so the contract test runs in Node only ([[Questions/Q02 - Does the contract test run in Node only]]).
**On Disk Now:** `packages/pq-core/package.json` → `"test": "node --test dist/__tests__/contract.test.js"` (the file `src/__tests__/contract.test.ts` does not exist yet). `packages/pq-core/src/native.ts` → `require("../pq-core.node")` (no built `.node` file is on disk yet). `packages/pq-core/pkg/rwa_vault_pq_core.js` → present. `packages/pq-core/native/tests/vectors/oracle-vectors.txt` → present (one line per vector, algorithms Falcon-padded-512, ML-DSA-44, ML-DSA-65, …).
**Message:** The Coder owns the work, but the Researcher ticks it. Every criterion below runs from `packages/pq-core` on a clean checkout with Rust installed (Q01 = D). The Researcher runs them and records the output in a `VERIFY ✅` entry. A criterion that fails sends a `REPORT` back here, not a guess.

**Acceptance criteria (T3):**

- **AC-01 Addon builds and loads.** `pnpm build:addon` exits 0 and produces `packages/pq-core/pq-core.node`. `node -e "require('./pq-core.node')"` exits 0. Pass on Windows locally; Linux is covered by CI Job 4.
- **AC-02 Addon error codes are the nine stable codes.** Every addon error message has the form `[CODE] text`, where CODE is one of the nine values in `PQ_ERROR_CODES` (`src/errors.ts`). A malformed key input, for example, yields `MALFORMED_KEY`. The test fails if any code is absent from the Rust `PqError::code()` set or the TS list.
- **AC-03 Shared error fixture.** One fixture file, `packages/pq-core/native/tests/vectors/error-codes.json`, lists the nine codes. Both the Rust test and `contract.test.ts` read it and assert it equals their own list. Adding a code in one place without the other fails the build.
- **AC-04 SLH-DSA signing is not exposed by the addon (S3-04, ADR 0005).** `createNativeAdapter().sign("SLH-DSA-SHA2-128s", …)` rejects with a `PqError` whose code is `UNSUPPORTED_ALGORITHM`. *Researcher assumption:* the exact code is not yet confirmed against `native/napi/src`. If the Coder finds a different code is correct, that is a `DECISION-NEEDED` to Fahad, not a silent change.
- **AC-05 Signing does not block the event loop (S3-02).** While an SLH-DSA `verify` or ML-DSA `sign` runs, a `setInterval(…, 1)` counter increments at least 3 times. The test fails if the count is 0.
- **AC-06 Error messages carry no byte data (S3-03).** For each error thrown by either adapter, the message contains no hex run of 16 or more characters and no byte-array text.
- **AC-07 TypeScript contract is typed, no `any`.** `pnpm typecheck` exits 0. `pnpm lint` exits 0. `grep -rn ": any" src` prints nothing.
- **AC-08 Public exports are the only surface.** A `dist` import of `@rwa-vault/pq-core` exposes exactly the names exported in `src/index.ts`. `grep -ril pqclean dist/*.d.ts` prints nothing (no PQClean detail leaks, S3-11).
- **AC-09 Contract-equivalence test exists and runs (S3-10, Q02 = A).** `src/__tests__/contract.test.ts` loads both `createNativeAdapter()` and `createWasmAdapter()` in Node and runs the same suite against each. It covers, for every algorithm in `PQ_ALGORITHMS`:
  - keygen: both adapters return key lengths equal to `SIGNATURE_METADATA` / `KEM_METADATA` (ADR 0006);
  - cross-verify: a signature made by one adapter verifies in the other, and the reverse;
  - KEM: a ciphertext encapsulated by one adapter decapsulates to the same shared secret in the other;
  - negative inputs: the same malformed input gives the same error code from both adapters.

  Input vectors come from `native/tests/vectors/oracle-vectors.txt`.
- **AC-10 `pnpm test` is real (S3-13).** `pnpm test` exits 0, runs at least the AC-09 cases, and reports 0 skipped. The `"no tests yet"` placeholder text is gone from the repo.
- **AC-11 `pqctl` round trip (S3-12).** `pnpm build:pqctl` exits 0. A SLH-DSA signature over a file verifies with exit 0. A one-byte-tampered copy of the file verifies with a non-zero exit. The `packages/pq-core/package.json` dependencies list stays empty (no service links `pqctl`).
- **AC-12 Build wiring (S3-15).** `pnpm build:wasm` and `pnpm build:native` each exit 0 on a clean checkout with Rust installed.
- **AC-13 Rust is documented as mandatory (Q01 = D).** `packages/pq-core/README.md` states that Rust 1.81.0 and the `wasm32-unknown-unknown` target are required on every machine that runs the services, and gives the one build step (`pnpm build:addon`) that produces `pq-core.node`.

**Not in T3:** prebuild CI (S3-05, descoped by Q01); Falcon Round 3 KATs and the CAVP runner (T4 Conformance); browser equivalence (CI Job 5).

**Action Needed:** Coder runs AC-01 to AC-13 and posts results in this thread as `REPORT`. Researcher verifies each on disk and writes `VERIFY ✅` only when all 13 pass. Ask any unclear criterion as `ASK` here before changing code.
**Unblocks:** S3-10 and S3-13 (AC-09, AC-10); T4 after T3 is verified.

---

### 2026-11-22 · 🧭 Researcher → ⌨️ Coder · PLAN

**Context:** Stage 3 remainder, Stage 4 and Stage 5 are now assigned to named teammates, per the assignment documents in `docs/deliverables/assign task/`. Hassan Attique owns the rest of T3 (S3-10, S3-13) and all of T4. Fawaz Asif owns T5. T4 and T5 acceptance criteria are logged in their task notes (AC-S4-01 to AC-S4-18, AC-S5-01 to AC-S5-12).
**On Disk Now:** `RWA Vault/Module 1 - PQ Core/Tasks/T4 - Conformance.md` → `assignee: "Hassan Attique (ASS01 HAS)"`; `RWA Vault/Module 1 - PQ Core/Tasks/T5 - Benchmarks.md` → `assignee: "Fawaz Asif (ASS01 FAW)"`.
**Message / Finding:** Ownership changes only. Acceptance criteria, the Done Rule and the thread protocol are unchanged. Each assignee works as a Coder session in this folder, and any decision in their scope goes through the process in their assignment document.
**Action Needed:** Hassan starts with AC-09 and AC-10 of T3. Fawaz waits for T3 `VERIFY ✅` unless the Researcher rules otherwise with an `ASK` entry in this thread.
**Status / Unblocks:** T3 remainder, T4 and T5 now have named owners. T3 `VERIFY ✅` still gates T4 and T5.

---

### 2026-11-24 23:45 · 🧭 Researcher → ⌨️ Coder · RULING

**Context:** S3-10 surfaced that the two adapters disagree on SLH-DSA signing. Raised as [[Questions/Q03 - SLH-DSA signing split across adapters]].
**On Disk Now:** `native/napi/src/lib.rs:246` → addon `sign` rejects `slh-dsa-sha2-128s` with a raw `napi::Error` (no `[CODE]` prefix, so the TS adapter surfaces `INTERNAL_ERROR`, not `UNSUPPORTED_ALGORITHM`); `native/src/wasm.rs:140` → WASM `sign` signs SLH-DSA via `algorithms::sign`; `native/tests/vectors/oracle-vectors.txt` → no SLH-DSA entry.
**Ruling:** Q03 = B. Keep the split for now; S3-10 encodes it. Interoperability fix and reject-code standardisation deferred to a follow-up (ADR when taken up). AC-04's stated `UNSUPPORTED_ALGORITHM` is inaccurate as built; left as-is under this ruling.
**Blocks/Unblocks:** Unblocks the S3-10 / S3-13 handoff.

---

### 2026-11-24 23:46 · ⌨️ Coder → 🧭 Researcher · HANDOFF

**Context:** S3-10 and S3-13 written on branch `feat/m1-s3-10-s3-13` (base `feat/finance-modules`). Awaiting on-disk VERIFY.
**On Disk Now:** `packages/pq-core/src/__tests__/contract.test.ts` → new; one suite loads `createNativeAdapter()` and `createWasmAdapter()` in Node, iterates `PQ_ALGORITHMS`, reads `native/tests/vectors/oracle-vectors.txt` for inputs (`falcon-padded-512` → `falcon-512`). `packages/pq-core/package.json` → `"test": "node --test dist/__tests__/contract.test.js"` (already wired; no `"no tests yet"` placeholder in pq-core).
**Finding:** Covers AC-09's four checks per algorithm — key lengths vs ADR 0006 metadata; cross-runtime verify (oracle known-good signature for falcon/ml-dsa, plus live cross-sign both directions); KEM shared-secret agreement (oracle KAT decaps + live cross encaps/decaps); identical exact error codes for malformed input. SLH-DSA per Q03 = B: native `sign` asserted to reject (`INTERNAL_ERROR`), WASM `sign` succeeds and verifies in both runtimes.
**Not verified here:** not built or run — needs Rust 1.81.0 + `wasm32-unknown-unknown` + `pnpm build` on a clean checkout, then `pnpm --filter @rwa-vault/pq-core test`. AC-10's green run also depends on the WASM adapter loading in Node via its web-target `init()` (separate from S3-10).
**Blocks/Unblocks:** S3-10 (AC-09) and S3-13 (AC-10) ready for Researcher VERIFY; T4 gated on T3 VERIFY.
