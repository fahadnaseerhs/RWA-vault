---
type: decision
id: M1-Q03
module: M1
status: decided
raised_by: researcher
raised_on: 2026-11-24
blocks: []
recommendation: "A — make both adapters reject SLH-DSA signing (keep the runtimes consistent)"
decision: "B — keep the current split (native addon rejects SLH-DSA sign, WASM signs). S3-10 encodes the split; the interoperability fix is deferred to a follow-up."
decided_by: "Fahad Naseer"
decided_on: "2026-11-24"
adr: none
tags: [rwa-vault, decision, m1, task3]
updated: 2026-11-24
---
# Q03 — How should SLH-DSA signing be handled across the two runtime adapters?

**Why it matters (plain words):** the native addon rejects `sign("slh-dsa-sha2-128s")` (S3-04 / ADR 0005) but the WASM
build signs it successfully, so the two runtimes disagree. Until this is stated, the contract-equivalence test (S3-10)
cannot be both correct and green, and nobody has recorded that an SLH-DSA signature produced in WASM will not round-trip
through the server addon.

**Blocks:** S3-10 (contract-equivalence test) · **Does not block:** S3-13.

## Context (on disk)
- `native/napi/src/lib.rs:246` — the addon `sign` rejects `slh-dsa-sha2-128s` with a raw `napi::Error` ("SLH-DSA signing
  is not available in the server addon..."). Because that message has no `[CODE]` prefix, the TS adapter's `wrapNapiError`
  surfaces it as `INTERNAL_ERROR`, not `UNSUPPORTED_ALGORITHM` — so AC-04's stated code is inaccurate as built.
- `native/src/wasm.rs:140` — the WASM `sign` calls `require_signature` then `algorithms::sign`, which signs SLH-DSA
  successfully (`native/src/slhdsa.rs:101`).
- `native/tests/vectors/oracle-vectors.txt` — has no SLH-DSA entry, so there is no reference signature to cross-verify.

## Options
- **Option A — reject in both adapters.** Make WASM also reject SLH-DSA `sign` and return a proper `UNSUPPORTED_ALGORITHM`
  code; the test asserts both reject identically. *Cost:* ~0.5 day (wasm.rs + napi error envelope + a small ADR).
  *Risk:* touches adapter code outside S3-10.
- **Option B — keep the split, test encodes it.** Leave native-rejects / WASM-signs; S3-10 pins that behaviour.
  *Cost:* ~0. *Risk:* enshrines a real cross-runtime inconsistency — an SLH-DSA signature is not portable between the
  server and the browser.

## Recommendation
**Option A**, because the point of PQ Core is that a signature made in one runtime verifies in the other; a permanent
SLH-DSA split undercuts that guarantee.

## Decision
> **B, decided by Fahad Naseer on 2026-11-24.** Keep the current split for now. S3-10 encodes it: native `sign(slh-dsa)`
> is asserted to reject (surfaces `INTERNAL_ERROR`), and WASM `sign(slh-dsa)` succeeds with its signature verifying in both
> runtimes. The interoperability fix — and whether to standardise the reject code to `UNSUPPORTED_ALGORITHM` — is deferred
> to a follow-up; open an ADR when it is taken up. No ADR written now; recorded as a test-scope decision.

Up: [[Decisions/Open Questions for Fahad]] · Related: [[Tasks/T3 - Runtime adapters]], [[Threads/Thread - T3 Runtime adapters]]
