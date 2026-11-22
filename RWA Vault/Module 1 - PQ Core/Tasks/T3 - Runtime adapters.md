---
type: task
id: M1-T3
module: M1
stage: 3
status: in-progress
agent: coder
assignee: "Hassan Attique (ASS01 HAS) for S3-10 and S3-13"
progress: 12/15
depends_on: [M1-T2]
unblocked_by: []
thread: "[[Threads/Thread - T3 Runtime adapters]]"
spec: "[[Specs/M1 Task Breakdown]]"
tags: [rwa-vault, m1, task]
updated: 2026-11-22
---
# 📋 T3 — Runtime adapters

**In plain words:** a Node addon (napi-rs) and a WASM adapter behind **one shared TypeScript interface**, plus the offline `pqctl` CLI.

## Blockers
| Blocker | Kind | Owner | Clears when |
|---|---|---|---|
| S3-10 (contract-equivalence test, Node only per [[Questions/Q02 - Does the contract test run in Node only]]) | task | ⌨️ Coder | ticked, then Researcher VERIFY ✅ |
| Acceptance criteria not yet written | process | 🧭 Researcher | PLAN entry in the thread |

## Subtasks
### Node addon
- [x] **S3-01** `native/napi/` addon crate: stateless `#[napi]` wrappers, Node-API v8, loads on Node 22.16
- [x] **S3-02** Async variants via `AsyncTask` (the default export); SLH-DSA signing must not block the event loop
- [x] **S3-03** Map `PqError` to a JS `Error` with stable `code` strings; no byte data in messages
- [x] **S3-04** **Exclude SLH-DSA signing from the addon** (verify only, ADR 0005)
- [ ] **S3-05** Prebuild CI for Linux + Windows — **descoped from MS1** by [[Questions/Q01 - Where do the prebuilt addon binaries live]] (D: Rust mandatory, revisit at release)

### TypeScript layer
- [x] **S3-06** `src/types.ts`: byte types, metadata types and the two unions; no `any`
- [x] **S3-07** `src/errors.ts`: error classes whose codes match Rust and the addon (shared fixture)
- [x] **S3-08** `src/native.ts`: typed adapter over the addon
- [x] **S3-09** `src/wasm.ts`: typed adapter and loader over `pkg/`, implementing the *same* interface
- [ ] **S3-10** Contract-equivalence test: one suite run against both adapters
- [x] **S3-11** `src/index.ts` public exports; no PQClean detail leaks

### CLI and tooling
- [x] **S3-12** `pqctl` CLI: offline root ceremony (SLH-DSA keygen/sign/verify over files); never linked into services
- [ ] **S3-13** Replace the `"no tests yet"` placeholder with a real `pnpm test` *(script updated, test file pending)*
- [x] **S3-14** Package exports map, `.d.ts` check, ESLint — **typecheck and lint pass**
- [x] **S3-15** Wire `build:wasm`, `build:native`, `build:addon`, `build:pqctl` to real commands
- [ ] **S3-16** Fix `src/native.ts`: it calls `require(...)` in an ESM package, where `require` is undefined, so `createNativeAdapter` cannot load. Use `createRequire(import.meta.url)`. *(Found by the M3 Coder in T6.1a, 2026-10-28; M3 works around it in `scripts/onboard/lib.mjs`.)*

### Expanded WASM boundary
The `wasm.rs` module was expanded from Falcon-only (Stage 1 slice) to all six primitives, matching the full `PqCoreApi` interface. The Stage 1 `FalconKeyPair` WASM struct was replaced by a generic `WasmKeyPair` and `WasmEncapsulation`.

### Remaining
- S3-05 is descoped for MS1 (Q01 = D). Rust is mandatory on every machine that runs the services.
- S3-10 (contract-equivalence test) needs the addon compiled first
- S3-13 (test script) pointed at the contract test file, which depends on S3-10

## Acceptance criteria (runnable by a third party)
Drafted 2026-11-22 as the Researcher's `PLAN` entry in [[Threads/Thread - T3 Runtime adapters]]: **AC-01 to AC-13**. The Coder starts from there. No `VERIFY ✅` until all 13 pass on disk.

---

Up: [[M1 Task Board and Todo]] · Hub: [[Module 1 - PQ Core]] · Thread: [[Threads/Thread - T3 Runtime adapters]] · Prev: [[T2 - Full algorithm matrix]] · Next: [[T4 - Conformance]]
