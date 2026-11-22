---
type: decision
id: M1-Q02
module: M1
status: decided
raised_by: researcher
raised_on: 2026-11-22
blocks: []
recommendation: "A — Node only: one suite loads both adapters in Node"
decision: "A — the contract-equivalence test runs in Node only. One suite loads the native addon and the WASM pkg/ build in Node and asserts identical results. Browser equivalence stays in CI Job 5."
decided_by: "Fahad Naseer"
decided_on: "2026-11-22"
adr: none
tags: [rwa-vault, decision, m1, task3]
updated: 2026-11-22
---
# Q02 — Does the contract-equivalence test run in Node only, or also in a real browser?

**Why it matters (plain words):** the native addon and the WASM build must give the same answer for every input, or a
signature made on the server would not verify in the browser. The test that proves this can run in two places. Node is
fast and simple. A browser is closer to the real user, but it is slower and needs a headless browser in CI.

**Blocks:** S3-10 (contract-equivalence test), S3-13 (`pnpm test` script) · **Does not block:** S3-05 (prebuild CI).

## Options
- **Option A — Node only.** One suite loads the native addon and the WASM `pkg/` in Node and runs the same vectors
  through both. *Cost:* ~0.5 day. *Risk:* does not catch a browser-only difference such as the Web Crypto random source (ADR 0007).
- **Option B — Node and browser.** The same suite also runs in a headless browser. *Cost:* ~1–2 days more. *Risk:*
  duplicates the browser equivalence work already planned in CI Job 5 (`packages/pq-core/browser-tests`).

## Recommendation
**Option A**, because S3-10 asks for "one suite run against both adapters", and browser equivalence is already covered
by CI Job 5. Keeping the browser case in Job 5 avoids testing it twice.

## Decision
> **A, decided by Fahad Naseer on 2026-11-22.** The contract-equivalence test runs in Node only. Browser equivalence
> stays in CI Job 5. No ADR written; this is a test-scope decision, not an architecture one.

Up: [[Decisions/Open Questions for Fahad]] · Related: [[Tasks/T3 - Runtime adapters]]
