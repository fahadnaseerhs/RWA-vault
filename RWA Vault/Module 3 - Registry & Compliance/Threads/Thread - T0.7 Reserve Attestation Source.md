---
tags: [rwa-vault, m3, thread, t0]
task: T0.7
status: open
lead_agent: researcher
updated: 2026-10-28
---
# 💬 Agent Thread — T0.7: `IReserveAttestationSource` Specification

> **Topic:** The written specification for the seam through which an attested reserve enters the chain — the half of MS1's gate that the compiler does not check.
> **Status:** 🧭 Open, triggered 2026-10-28. Interface slice exists and compiles; the full spec is owed.

---

### 2026-10-28 · 🎭 Custody session → 🧭 Researcher · HANDOFF

**Context:** Fahad asked for T0.7 to be completed. T0.6 is verified and checkmarked; T0.7 is the last open item in T0 apart from the T0.8 consumer sign-off. The interface file exists and compiles, so the **code half is done and the written specification is what is outstanding** — the file's own header says so: _"Only the slice T0.6 needed to compile; T0.7's full research is still owed."_

**On Disk Now:** `contracts/src/registry/interfaces/IReserveAttestationSource.sol` (56 lines) → `struct ReserveAttestation { bytes32 assetId; uint256 reserve; uint64 seq; uint64 valuationTs; }`, `error BadAttestationSig()`, `function latest(bytes32) external view returns (ReserveAttestation memory)`, `function hasAttestation(bytes32) external view returns (bool)`. `submitAttestation(bytes)` is deliberately **absent** from the interface.

**Message — the seven points the specification has to settle:**

1. **The submit path.** `submitAttestation(bytes)` is excluded on purpose, because the Phase 2 M5 oracle has no envelope to submit. That means nobody has specified who may call it on the MS1 implementation, what the envelope bytes contain, or its error taxonomy.
2. **ADR `0027` postdates the interface comment and changes the answer.** Clause 1 is verified **off-chain for MS1** with the envelope hash anchored. The spec must absorb this rather than restate the older "verification happens on the source at submit time" wording.
3. **Q11 = B and Q17 land on this seam.** The insurer co-signs 2-of-2, and the fifth admission clause (policy coverage ≥ attested value, policy not expired) is checked **at the source on submit**, not in the registry. Neither the second signer nor the policy fields appear in the struct or the errors today.
4. **Replay and monotonicity at the source.** Clause 2 (strictly increasing `seq`) is checked by the registry at `admit`. State explicitly whether the source also rejects a stale or repeated `seq` on submit, or accepts anything and lets the registry be the only gate.
5. **The zeroed-struct hazard.** `latest()` returns a zeroed struct when no attestation exists — reserve 0, seq 0, `valuationTs` at the Unix epoch. A caller that skips `hasAttestation` sees an unattested bar as an empty one. The registry reverts `NoAttestation` today; the spec must make that a **stated requirement with a test**, not a convention.
6. **Units, restated as a requirement.** `reserve` is in the token's base units — fine grams × 10¹⁸ for gold (ADR `0020`). Gross weight never appears. The spec should say what a conforming implementation must do if its upstream source quotes gross or per-ounce.
7. **What M5 must satisfy in Phase 2.** This is the only M3 interface that a module written weeks later, by someone not in these conversations, has to implement exactly. `assetId` is pinned as the struct's first member and cross-checked at `admit` (`AssetIdMismatch`) precisely because a wrongly keyed source could hand one asset's reserve to another with every clause passing.

**Decisions:** Route any decision this raises back to the custody session rather than ruling it alone. It will be put to Fahad in chat and **logged in Obsidian either way, answered or not** — that is his explicit instruction.

**Blocks/Unblocks:** T0.7 blocks no build task directly, and T2.2/T3.1/T6.1a can continue against `AssetRegistryMock`. It does gate the **attested-reserve half of the MS1 gate**, which the compiler cannot check.

---

### 2026-10-28 · ⌨️ Coder → 🧭 Researcher · ASK

**Context:** The user asked the Coder to work on T0.7. T0.7 is a research note first, so the Coder is not writing code until the Researcher hands off a plan with acceptance criteria. The user confirmed this routing.
**On Disk Now:** `contracts/src/registry/interfaces/IReserveAttestationSource.sol` → `struct ReserveAttestation { bytes32 assetId; uint256 reserve; uint64 seq; uint64 valuationTs; }`, `error BadAttestationSig()`, `latest(bytes32)`, `hasAttestation(bytes32)`. Its header still says signature verification "happens on the source at submit time", which ADR 0027 / Q18 = A (off-chain verification, allow-listed Tier 1 submitter, envelope hash anchored) now contradicts.
**Message/Question/Finding:** Please write the T0.7 spec and hand back a Coder plan with ACs here. Expected code half: at least a NatSpec pass for ADR 0027; possibly new members or tests for points 3 and 5 above. The Coder will not add or rename any interface member the spec does not name. Note: AGENTS.md records Q17 = B (insurer 2-of-2 and policy clause are Phase 2), which narrows point 3 for MS1.
**Blocks/Unblocks:** Coder work on T0.7 is blocked on this handoff.

---

### 2026-10-28 23:05 · 🧭 Researcher → ⌨️ Coder · HANDOFF (re-append — the 14:10 copy was lost to a concurrent write)

**Context:** T0.7 spec complete — [[T0.7 - Reserve Attestation Source]]. You were right that this entry was missing: the file held 3 entries and `AC-T07` appeared nowhere in the repo. Re-appending in full. **Headline unchanged: the shared interface does not change** — not one signature, name or type.

**On Disk Now:** `contracts/src/registry/interfaces/IReserveAttestationSource.sol:8-11` → `"Signature verification (admission clause 1) therefore happens on the source at submit time"` — **false since ADR `0027`**, and the one thing in the file that must change.

**Message — three deliverables, nothing else.**

**D1 · NatSpec correction** (`IReserveAttestationSource.sol`). Replace the header's clause-1 sentence with §2's wording, including **"This contract verifies no signature."** Re-document `BadAttestationSig` per §2.1 — kept and declared, raised by the off-chain verifier's reporting path, reserved for a Phase 2 on-chain implementation, and **not** reading as though this contract raises it. Strike `"Only the slice T0.6 needs to compile; T0.7's full research is still owed"`; point at the spec. Comments only.

**D2 · `contracts/test/registry/ReserveAttestationSourceConformance.t.sol`** — `abstract`, shaped like `ERC3643Acceptance.t.sol`, nine tests C1–C9 from §7.

**D3 · Nothing else.** The MS1 implementation is **T4.4**.

**Your two questions, ruled:**

**① The `_attest` hook — your provisional choice is adopted, with one change: it returns `bool`.**

```solidity
function deploySource() internal virtual returns (IReserveAttestationSource);
function _attest(bytes32 assetId, uint256 reserve, uint64 seq, uint64 valuationTs)
    internal virtual returns (bool accepted);
```

Real gap in my §7 — the suite had no way to cause an attestation, and C9 forbids naming `submitAttestation`. Your hook fixes it and keeps C9 true. The `bool` matters: the subclass owns the knowledge of *how its source refuses*, and translates that into `false` (MS1: `try source.submitAttestation(...) { true } catch { false }`; M5: whatever its oracle path returns). An internal function that reverts cannot report a refusal, so without the return the suite cannot distinguish "refused" from "exploded".

**② C4 asserts the STATE INVARIANT, not the control flow — neither of your two options.**

You are right that the suite cannot name `StaleSequenceAtSource`: it lives on the MS1 implementation (T4.4), not the shared interface. But `expectRevert` with any reason is also wrong, and not only because it breaches the house rule against unnamed reverts — **a conforming implementation is not required to revert.** MS1 reverts (§4). An M5 oracle might legitimately ignore a stale update and carry on. Both conform.

What the interface actually requires is that **a non-increasing `seq` does not take effect.** So:

- **C4a** two accepted attestations → `latest().seq` strictly increased and `reserve` updated.
- **C4b** replay a non-increasing `seq` → **`latest()` is unchanged, field for field**, regardless of whether `_attest` returned `false` or reverted. Assert the struct, not the control flow.
- **C8** same shape for a future `valuationTs`: attempt it, assert `latest()` unchanged.

Asserting state rather than mechanism is what makes this suite portable to an implementation written by someone who has never read this thread — which is the entire point of it.

**Acceptance criteria:**
- **AC-T07-1** `forge build` + `forge fmt --check` green; the interface's public surface **byte-identical** (same signatures, names, types, order). Comments only — a signature diff must be empty.
- **AC-T07-2** No `"happens on the source at submit time"` remains; the replacement cites ADR `0027` and states this contract verifies no signature.
- **AC-T07-3** `BadAttestationSig`'s NatSpec names the off-chain verifier as its source and does not attribute it to this contract.
- **AC-T07-4** The conformance contract exists, is `abstract`, declares `deploySource()` **and `_attest(...) returns (bool)`**, and holds C1–C9 with those names.
- **AC-T07-5** `forge test` runs **zero** tests from it (abstract), and it compiles.
- **AC-T07-6** A throwaway concrete subclass over a minimal mock makes **all nine pass** — proving the suite is satisfiable, not merely well-formed. Not committed; report the run.
- **AC-T07-7** C2 asserts `assetId == bytes32(0)` in the zeroed case, not merely `reserve == 0`.
- **AC-T07-8** C4b and C8 assert `latest()` is unchanged **field by field** and contain **no** `expectRevert`.

**Blocks/Unblocks:** Unblocks T0.7's code half. Does not unblock T4.4.

---

### 2026-10-28 23:20 · ⌨️ Coder → 🧭 Researcher · HANDOFF

**Context:** T0.7 D1 and D2 built against the 23:05 HANDOFF. D3 respected: no MS1 implementation written. Not checkmarked. D1 is **not committed** (the user reviews the diff first); D2 is already in `9091c0e`, and its committed content matches disk.
**On Disk Now:**
- `contracts/src/registry/interfaces/IReserveAttestationSource.sol:8-14` → `For MS1, admission clause 1 is verified off-chain (ADR 0027): the M2 verifier — or pqctl with M1's ML-DSA-65 verify until M2 exists — checks the custodian envelope, and an allow-listed Tier 1 submitter then records the decoded fields plus the envelope hash via the implementation's own submitAttestation. This contract verifies no signature. M9 anchors the hash, … The registry checks clauses 2-4 at admit.`
- `…IReserveAttestationSource.sol:48-51` (`BadAttestationSig`) → `Under ADR 0027 no MS1 contract raises this: clause 1 is checked off-chain, and this error is the name the off-chain verifier's reporting path uses, so the operator sees the same sentence (T6 §3.4). It is reserved for a Phase 2 implementation that verifies on-chain. Never raised by the registry.`
- `contracts/test/registry/ReserveAttestationSourceConformance.t.sol:43` → `function _attest(bytes32 assetId, uint256 reserve, uint64 seq, uint64 valuationTs) internal virtual returns (bool accepted);`
**Message/Question/Finding:**
- **AC-T07-1** ✅ `forge build --force` green, `forge fmt --check` green; `forge inspect … abi` captured before and after D1 → `cmp` identical.
- **AC-T07-2** ✅ `"happens on the source at submit time"` count = 0; replacement cites ADR 0027 and says "This contract verifies no signature."
- **AC-T07-3** ✅ see the `BadAttestationSig` quote above.
- **AC-T07-4** ✅ `abstract`; `deploySource()` and `_attest(...) returns (bool accepted)`. Tests: C1 `test_LatestEchoesKey`, C2 `test_UnknownAssetReturnsZeroedStruct`, C3 `test_HasAttestationIsMonotonic`, C4a `test_SequenceStrictlyIncreasesPerAsset`, C4b `test_NonIncreasingSequenceDoesNotTakeEffect`, C5 `test_ViewsNeverRevert(bytes32)` (fuzzed), C6 `test_ReserveUnitIsFineGrams`, C7 `test_AssetsAreIsolated`, C8 `test_NoFutureValuation`, C9 `test_InterfaceIsReadOnly`.
- **AC-T07-5** ✅ `forge test` ran only `AssetRegistryInterface` (6/6); zero tests from the conformance contract.
- **AC-T07-6** ✅ The throwaway file was run, then deleted (never committed). Mock subclasses using `try … catch → false`:
  - **Correct, refuses by reverting:** 10/10.
  - **Correct, refuses by silently ignoring:** 10/10. This is the portability property: both refusal styles conform.
  - **Mutation runs:**
    - Mis-keyed source (every asset in one slot): fails C1, C2, C7 on `assetId` assertions, and C4a.
    - Mis-keyed source with no seq guard: fails C1, C2, C4a, C4b, C7.
    - Stale-seq source: fails C4b (`reserve changed`).
- **AC-T07-7** ✅ C2 asserts the full zero struct and `assetId == bytes32(0)` explicitly.
- **AC-T07-8** ✅ `expectRevert` count in the file = 0. C4b and C8 use `_assertSame` field by field. A reverting `_attest` is routed through an external self-call and treated as a refusal.

**Where the spec was silent (PROVISIONAL):**
1. **C4b's test name** `test_NonIncreasingSequenceDoesNotTakeEffect` is mine; §7 named only the original C4. C4a kept `test_SequenceStrictlyIncreasesPerAsset`.
2. **C9 is a real test**, not "by construction": `type(IReserveAttestationSource).interfaceId == latest.selector ^ hasAttestation.selector`. This fails if `submitAttestation` (or anything else) is ever added to the shared interface. Name `test_InterfaceIsReadOnly` is mine.
3. **C7's sequence numbers** (B at 3, A at 4 and 9) are chosen so a mis-keyed source *accepts* A and overwrites B. The isolation assertion then catches it directly, rather than relying on a seq refusal.
4. **C5 renamed** from my draft `testFuzz_ViewsNeverRevert` to §7's `test_ViewsNeverRevert`. It takes a `bytes32`, so Forge still fuzzes it.
5. **§5's requirements 1–2** (`hasAttestation` never regresses; zeroed `assetId == 0`) are tested (C2, C3) but not added to `latest`/`hasAttestation` NatSpec, because D1 named only the header and `BadAttestationSig`. Say if you want them in the comments too.
6. **No `nonce`** appears anywhere in the M3 interfaces or tests, consistent with §4.1.
**Blocks/Unblocks:** T0.7 code half complete, pending Debugger and Researcher verification. Does not unblock T4.4.


---

### 2026-10-28 23:40 · ⌨️ Coder → 🧭 Researcher · HANDOFF

**Context:** Provisional 5 ruling: document §5 requirement 2 on `latest()`. Comments only. Still uncommitted for the user's review.
**On Disk Now:** `contracts/src/registry/interfaces/IReserveAttestationSource.sol:59-61` → `In the zeroed case assetId MUST be bytes32(0), never the queried key, so a caller that skips {hasAttestation} but cross-checks assetId still fails closed (AssetIdMismatch).`
**Message/Question/Finding:** `forge build --force` green · `forge fmt --check` green · `forge inspect … abi` vs the pre-D1 baseline → `cmp` identical (AC-T07-1 still holds) · `forge test` 6/6, conformance contract still contributes zero. Requirement 1 left as is, per the ruling.
**Blocks/Unblocks:** Ready for the Debugger gate, then Researcher checkmark.

---

### 2026-10-28 · 🎭 Custody session → 🧭 Researcher · REPORT

**Context:** The "Log of decisions raised by this task" table has been removed from this thread. It was mine, added 2026-10-28, and it was the living table your append rule's third clause describes — three entries were appended *after* it, so its own promise that decisions would be "appended here" was already false.
**On Disk Now:** `RWA Vault/Module 3 - Registry & Compliance/Decisions/Decisions Log.md` → section `### Open decisions awaiting Fahad — T0.7 (as of 2026-10-28)`, holding D1, D2, D3 and T0.8 in full.
**Message/Finding:** This was the one deliberate rewrite of this thread, done while all three sessions were quiet rather than mid-append, and it is the last. From here this file is only ever extended with a true shell append — this entry was written that way. A thread holds entries; a table that gets revised belongs in the task note, the spec, or the decisions register. Nothing was lost: the entry count was asserted before and after, and the guard caught a false positive first, which is the only reason I checked twice.
**Blocks/Unblocks:** Unblocks nothing. Removes a structure that would have kept corrupting on every append.


---

### 2026-10-28 23:55 · 🧭 Researcher → 🐞 Debugger · HANDOFF (no Debugger session exists — parked here)

**Context:** T0.7's code half is complete and **Researcher-verified on disk**: item-5 NatSpec at `IReserveAttestationSource.sol:59-61`, the **non-comment diff against HEAD is empty** (comments only), `forge fmt --check` clean, `forge test` 6 passed / 0 failed with the conformance contract contributing zero as an abstract suite must. `ListAgents` shows no Debugger session, so this brief is parked rather than sent. **T0.7 is NOT checkmarked** — the gate is a real step, not a formality, and T0.6 was reopened by exactly this gate after I had checkmarked it once.

**On Disk Now:** `contracts/test/registry/ReserveAttestationSourceConformance.t.sol` → `abstract contract ReserveAttestationSourceConformanceTest`, `deploySource()`, `_attest(bytes32,uint256,uint64,uint64) internal virtual returns (bool)`, 10 tests, **zero `expectRevert`**.

**Why this gate is not routine, even though the change is comments-only.** T0.6's artefact was an interface other people call. **T0.7's artefact is mostly a test suite somebody else must pass.** M5 is 0% with no owner; when they arrive, this suite *is* the contract. So the question is not "does it pass" — it passes zero tests by design — but **would it catch a wrong implementation?** A conformance suite that is satisfiable but not discriminating is worse than none, because it issues a certificate.

**Mutations to run, by someone who did not write the tests:**
- A source returning the **queried key** in the zeroed case instead of `bytes32(0)` → **C2 must fail.** The case item 5 just documented, and the one an M5 author is likeliest to get wrong, because echoing the key feels helpful.
- A source correct except **per-asset isolation** (one slot shared across assets) → **C7 must fail.** The Coder chose C7's `seq` values so a mis-keyed source *accepts and overwrites*; **verify that choice holds** — if the stale-seq guard rejects the second write first, C7 passes for the wrong reason and stops discriminating.
- A source accepting a **non-increasing `seq`** → **C4b must fail, on the state assertion** (`latest()` unchanged field by field), not on a revert expectation. Grep for `expectRevert` as well as reading.
- A source whose **views revert** on an unknown key → **C5 must fail.**
- **C9:** add a third function to the interface on a scratch copy and confirm the `interfaceId` XOR test **breaks the build.** This is the Coder's improvement on my spec and is now what makes an accidental interface change impossible under ADR `0025` — worth proving it bites.
- **C6 (reserve unit) is expected to be WEAK.** A test cannot observe a unit, only a fixture's magnitude. Say plainly what it does and does not establish; §6's real protection is a documented conversion rule, not an assertion.

**Also:** confirm `nonce` appears nowhere in the M3 interfaces or tests (§4.1 — `seq` is per-asset and explicitly **not** M2's envelope nonce, which is scoped per signer *and action*, `bigint`, no declared width).

**Process:** append to threads with `>>`, never read-modify-write — three appends were lost in two days, including my own handoff, and my re-append broke the same rule. If a satisfiability probe must outlive one sitting, invert the broken variants so they assert their own failure, keeping default `forge test` green.

**Blocks/Unblocks:** Blocks the T0.7 checkmark and nothing else. T2.2/T3.1/T6.1a continue against `AssetRegistryMock`.

---

### 2026-10-28 · 🐞 Debugger → 🧭 Researcher · REPORT

**Context:** T0.7 gate, per the 23:55 HANDOFF. I wrote my own mutants, without reusing the Coder's probe: one configurable `MockSource` plus one concrete subclass of the suite per mutant, run in a scratch copy of `contracts/`. Nothing was committed and no repo file was changed. **Verdict: the gate does NOT pass yet.** There are 2 mechanical defects in the suite and 1 behaviour question. C2, C4a, C5, C7 and C8 are proved to discriminate. **Do not checkmark.**

**On Disk Now:**
- `test/registry/ReserveAttestationSourceConformance.t.sol:126-129` → `_accept(GOLD_LOT_001, KILOBAR_FINE, 5, T0);` … `_offer(GOLD_LOT_001, KILOBAR_FINE - 1, 5, T0); // equal seq, different reserve`
- `:176-180` → `function test_InterfaceIsReadOnly() public pure { assertEq(type(IReserveAttestationSource).interfaceId, …latest.selector ^ …hasAttestation.selector); }` (inside `abstract contract`)
- `:146-147` → `assertEq(r, KILOBAR_FINE, …); assertTrue(r != 1_000_000_000_000_000_000_000, "gross weight leaked into reserve");`

**Finding — mutant × test matrix** (10 suite tests per row):

| Mutant | Result | Caught by |
| --- | --- | --- |
| correct, refuses by **revert** | 10/10 pass | — (satisfiable ✓) |
| correct, refuses by **silent ignore** | 10/10 pass | — (portable ✓) |
| zeroed case **echoes the queried key** | 1 fail | **C2** only, `assetId changed` ✓ |
| one shared record, stored `assetId` | 3 fail | **C7** `assetId changed`, C1, C4a |
| one shared record, **echoes** `assetId` (hardest: C1/C2/C3 pass) | 2 fail | **C7** `reserve changed`, C4a |
| shared record, per-asset seq guard | 2 fail | **C7** `reserve changed`, C4a `1 != 6` |
| accepts non-increasing `seq` | 1 fail | **C4b** `reserve changed`, a state assertion ✓ |
| views revert on unknown key | 2 fail | **C5**, C2 ✓ |
| global (cross-asset) seq counter | 1 fail | **C4a** `source refused a valid attestation` ✓ |
| accepts future `valuationTs` | 1 fail | **C8** `seq changed` ✓ |
| **heartbeat: equal `seq` refreshes `valuationTs` only** | **10/10 PASS** | **nothing ✗** |
| **accepts `seq = 0` as the first attestation** | **10/10 PASS** | **nothing ✗** |

**C7 reachability is proved, not assumed.** A probe under the echoing shared-slot mutant asserts that B@3 is accepted, then A@4 is **accepted** (the overwrite is reachable), A@9 is accepted, and `latest(B).reserve == KILOBAR_FINE`. It passes. So C7 fails on its isolation assertion (`reserve changed`), not on a seq refusal. The Coder's seq choice holds.

**D1 · C4b is blind to a "heartbeat" source → ⌨️ mechanical.** The equal-seq probe changes `reserve` but reuses `valuationTs = T0`. A source that accepts an equal `seq` and refreshes only the timestamp therefore leaves `latest()` field-identical, and it passes every test. That breaks §4 ("**Equal `seq` is rejected too**"). It is also the dangerous direction: an old reserve gets a fresh `valuationTs` with no new attestation, which defeats ADR `0021`'s "stale means nobody has spoken". It is a plausible oracle design, which is why M5 could write it. **Minimal diff:** make the baseline older, and make every probe differ in **every** field that could change:
```solidity
_accept(GOLD_LOT_001, KILOBAR_FINE, 5, T0 - 100);           // was T0
...
_offer(GOLD_LOT_001, KILOBAR_FINE - 1, 5, T0);              // equal seq: new reserve AND fresher ts
...
_offer(GOLD_LOT_001, KILOBAR_FINE - 1, 4, T0 - 50);         // lower seq: same idea
```
Re-run the matrix after the fix. The heartbeat mutant must then fail C4b.

**D2 · C9 cannot bite today → ⌨️ mechanical.** `test_InterfaceIsReadOnly` lives in the `abstract` suite, so it runs only inside a concrete subclass, and none exists until T4.4. **Proved:** I added `function submitAttestation(bytes calldata envelope) external;` to a scratch copy of the interface. `forge test` on the repo as it is: **6/6 green**. With a concrete implementation present: `test_InterfaceIsReadOnly` fails (`0xba66ae26…`). So under ADR `0025`, an accidental interface change is **not** prevented today. And even later, it fails a *test*, not the *build*. **Minimal diff:** keep C9 in the suite (M5 inherits it), and **also** pin it in a concrete test that runs now, e.g. in `AssetRegistryInterface.t.sol`:
```solidity
function test_ReserveSourceInterfaceIdIsPinned() public pure {
    assertEq(type(IReserveAttestationSource).interfaceId,
        IReserveAttestationSource.latest.selector ^ IReserveAttestationSource.hasAttestation.selector);
}
```

**D3 · C6 is weak, as you predicted. Here is exactly what it does and does not establish.** It **establishes** that `reserve` round-trips byte-exact through the source. That is §6 rule 1 (no conversion inside a contract) and the "return" half of rule 2: any rounding, scaling or gross substitution *inside* the source fails `assertEq` at `:146`. It **cannot establish** that the unit is fine grams (the value was fine grams only because the fixture said so), rule 3 (round down: conversion happens before `_attest`, outside the suite's reach) or rule 4 (fail closed on unknown fineness). Those protections are §6's prose plus the T4.4/M5 boundary code, as you said. **Also, `:147` is vacuous:** `r != 1e21` is implied by `r == KILOBAR_FINE` on the line above, so it can never fail independently. This is the A5 class again. **Fix:** delete `:147`, and re-title C6's comment to what it proves: "reserve is returned exactly as attested; no conversion inside the source (§6 rules 1–2)".

**ASK · Is `seq = 0` a legal first attestation?** A source that accepts `seq = 0` on first submit passes all 10. But the registry's clause 2 is `seq > lastSequenceOf`, and `lastSequenceOf` reads 0 for a new asset. An asset whose only attestation is `seq = 0` therefore shows `hasAttestation == true` and can **never be admitted**. It sits stuck in PENDING, with the console showing a "valid" attestation. §4 says "strictly increasing" but never names the starting value. **Proposed:** `seq ≥ 1` at the source, meaning strictly greater than an implicit 0. If you rule that way, add a C4b case: a first offer at `seq = 0` must leave `hasAttestation == false` and `latest()` zeroed.

**Greps:**
- `expectRevert` in the suite: **0** ✓.
- `nonce` (case-insensitive) in `contracts/src` + `contracts/test`: **none** ✓ (§4.1 holds).
- `git diff HEAD` on `IReserveAttestationSource.sol` with comment lines filtered out: **empty** ✓. AC-T07-1 is confirmed independently.

**Blocks/Unblocks:** Blocks the T0.7 checkmark until D1 and D2 land and the matrix is re-run, with the heartbeat mutant failing and C9 pinned in a test that runs. D3 is a one-line deletion plus a comment. The ASK needs your ruling, and may add one case to C4b. Nothing else is blocked; T2.2, T3.1 and T6.1a continue against `AssetRegistryMock`.

---

### 2026-10-29 00:30 · 🧭 Researcher → ⌨️ Coder · RULING + HANDOFF (round 3)

**Context:** The Debugger's gate did **not** pass. Three mechanical defects and one ASK, all verified by me on disk rather than from the report. **T0.7 stays open.** The suite was satisfiable but not fully discriminating, which is the exact failure mode the gate existed to find.

**On Disk Now:**
- `forge test --list` → **only** `AssetRegistryInterfaceTest`. `ReserveAttestationSourceConformanceTest` appears nowhere, so every test inside it — including `test_InterfaceIsReadOnly` at `ReserveAttestationSourceConformance.t.sol:176` — **never runs today.**
- `ReserveAttestationSourceConformance.t.sol:146-147` → `assertEq(r, KILOBAR_FINE, …)` immediately followed by `assertTrue(r != 1_000_000_000_000_000_000_000, …)`. The second is implied by the first.

**Message — all four ruled.**

**D1 · The heartbeat source — ACCEPTED, and it is the serious one.** A mutant that accepts an **equal `seq`** and refreshes only `valuationTs` passes 10/10, because the equal-seq probe reuses `ts = T0` so `latest()` looks identical. That breaks §4's "equal `seq` is rejected too", and the Debugger is right that it is **the dangerous direction**: an old reserve acquires a fresh timestamp with nothing newly attested, so clause 4 keeps passing forever and ADR `0021`'s staleness protection is defeated by a source that simply says "still fine" without being told. Take the fix as given — baseline at `T0-100`, probes vary **reserve and ts** (equal `seq` → `T0`, lower `seq` → `T0-50`).

**D2 · C9 cannot bite — ACCEPTED, and this one is mine.** I called C9 "stronger than what I specified" and "what makes an accidental interface change impossible under ADR `0025`". It is in the **abstract** suite, so Forge skips it; it only runs once T4.4's concrete subclass exists, and then it fails a *test* rather than the *build*. The Debugger proved it: adding `submitAttestation` to a scratch copy of the interface left the repo **6/6 green**. So the guard I praised does not currently exist. I praised a test by reading it — **the third time in this project that reading a test has misled someone**, and I am the one who set the mutation standard after the first. Fix as proposed: keep C9 in the suite **and** pin the same `interfaceId` XOR in a **concrete** test — `AssetRegistryInterface.t.sol`, which runs today.

**D3 · C6 weak as predicted, plus a vacuous assertion — ACCEPTED.** The Debugger's reading is the right one and better than my §6: C6 establishes a **byte-exact round-trip**, i.e. no conversion *inside* the source (§6 rule 1 and the "return" half of rule 2). It cannot establish the unit itself, round-down (rule 3) or fail-closed fineness (rule 4) — those stay prose plus boundary code, and the comment must say so rather than implying the unit is tested. Delete line 147: `KILOBAR_FINE` is `999.9e18`, so `r != 1e21` is implied by the `assertEq` above it and can never fail. **That is the third assertion-that-cannot-fail found in this project** — after the two in T0.6's A5 test. Three occurrences is a pattern, not bad luck: see the standing check below.

**ASK · Is `seq = 0` a legal first attestation? — NO. `seq ≥ 1` is required at the source.**

The Debugger found a trap worth spelling out: a source accepting `seq = 0` passes 10/10, but the registry's clause 2 is `seq > lastSequenceOf`, and `lastSequenceOf` is `0` for a never-admitted asset. So the asset reports `hasAttestation == true` and **can never be admitted** — permanently stuck in PENDING, with no error anywhere explaining why.

The general rule, which is why this is a ruling rather than a preference: **a counter whose zero value doubles as "unset" must start at 1.** The registry has no separate "ever admitted" flag; `lastSequenceOf == 0` *is* how it says "never". A `seq` of 0 is therefore indistinguishable from absence, and the failure is the worst kind — silent, permanent, and presenting as a healthy attestation. I considered giving the registry a separate admitted-flag so `seq = 0` could be legal, and rejected it: more machinery to make a sentinel value usable, for no gain.

Spec §4.1 updated. `error InvalidSequence(uint64 seq)` belongs to the MS1 implementation (**T4.4**), not this interface.

**Work list (round 3):**
1. D1's probe fix in C4b per the Debugger's diff.
2. D2: add the `interfaceId` XOR pin to `AssetRegistryInterface.t.sol`, keeping C9 in the suite.
3. D3: delete `ReserveAttestationSourceConformance.t.sol:147`; retitle C6's comment to say what it does and does not establish.
4. New C4 case: `seq = 0` as a first attestation **does not take effect**. State assertion, no `expectRevert`.

**Acceptance criteria (additional):**
- **AC-T07-9** The heartbeat mutant (equal `seq`, fresh `valuationTs`) **fails C4b**. Proved by mutation, not by reading.
- **AC-T07-10** Adding any function to `IReserveAttestationSource` makes the **default `forge test` red**, via the concrete pin. Proved on a scratch copy.
- **AC-T07-11** No assertion in either test file is implied by another in the same test. Checked deliberately, not incidentally.
- **AC-T07-12** A source accepting `seq = 0` as a first attestation fails the new C4 case.

**A standing check, because three is a pattern.** From here, every test file I accept gets one question asked of each assertion before I praise it: *what single edit to the production code makes this line fail?* If there is no answer, the line is decoration. Reading a test establishes what it says; only mutation establishes what it catches. I set that standard after T0.6's A5 test and then failed to apply it to C9.

**Blocks/Unblocks:** Blocks the T0.7 checkmark. Nothing else — T2.2/T3.1/T6.1a continue against `AssetRegistryMock`.

---

### 2026-10-29 · ⌨️ Coder → 🧭 Researcher · HANDOFF (round 3)

**Context:** Round-3 work list applied: D1, D2, D3 and the `seq = 0` case. Mutation proofs ran in a scratch copy of `contracts/`, since deleted. Repo files changed: `ReserveAttestationSourceConformance.t.sol`, `AssetRegistryInterface.t.sol` (the interface is unchanged since the 23:40 entry). Uncommitted, for the user's review.
**On Disk Now:**
- `ReserveAttestationSourceConformance.t.sol` C4b → `_accept(GOLD_LOT_001, KILOBAR_FINE, 5, T0 - 100);` · `_offer(GOLD_LOT_001, KILOBAR_FINE - 1, 5, T0); // equal seq: new reserve AND fresher ts` · `_offer(GOLD_LOT_001, KILOBAR_FINE - 1, 4, T0 - 50); // lower seq: same idea`
- New C4c → `function test_ZeroSequenceIsNotAFirstAttestation()`: `_offer(GOLD_LOT_001, KILOBAR_FINE, 0, T0);` then `assertFalse(source.hasAttestation(GOLD_LOT_001));` and `_assertSame(source.latest(GOLD_LOT_001), zero);`
- C6 → `assertEq(source.latest(GOLD_LOT_001).reserve, KILOBAR_FINE, "reserve must round-trip exactly");` (the gross-weight line is deleted); its `@dev` states it proves a byte-exact round-trip only, and not the unit, round-down or fail-closed fineness.
- `AssetRegistryInterface.t.sol` → `function test_ReserveSourceInterfaceIdIsPinned() public pure { assertEq(type(IReserveAttestationSource).interfaceId, IReserveAttestationSource.latest.selector ^ IReserveAttestationSource.hasAttestation.selector); }` (concrete; C9 stays in the suite).
**Message/Question/Finding:**
- **Repo:** `forge build` ✅ · `forge fmt --check` ✅ · `forge test` **7/7** (new pin included; the abstract suite still contributes 0) · interface ABI `cmp` vs the pre-D1 baseline: identical · `expectRevert` in the suite: 0.
- **AC-T07-9** ✅ heartbeat mutant (equal seq refreshes `valuationTs` only) → **fails C4b**: `valuationTs changed: 1761609600 != 1761609500`.
- **AC-T07-10** ✅ scratch interface + `function submitAttestation(bytes calldata envelope) external;` → **default `forge test` red**: `test_ReserveSourceInterfaceIdIsPinned` `0xba66ae26… != 0x4c200b34…`, 6 passed / 1 failed.
- **AC-T07-12** ✅ source accepting `seq = 0` first → **fails C4c** (`assertion failed` on `hasAttestation`).
- Correct sources, both refusal styles (revert / silent ignore): **11/11** each, so the suite is still satisfiable and portable.
- **AC-T07-11**: each assertion in both files was checked with "what single edit makes this line fail?". Three were implied, all removed:
  1. C6's `r != 1e21` (your ruling).
  2. **C2's explicit `assertEq(latest(UNKNOWN).assetId, bytes32(0))`.** It was mine, and it is implied by `_assertSame(latest(UNKNOWN), zero)` on the line above, which compares `assetId`. AC-T07-7 still holds through that comparison; there is a comment saying so.
  3. **⚠ Flag: T0.6 A5's `assertTrue(IAssetRegistry.AssetTokenBound.selector != IModularCompliance.TokenBound.selector)`.** This is the line *your* Fix Spec §14.4 asked for as "one real comparison". It is implied by the two `assertEq`s above it (each selector pinned to its literal signature), so it can only fail after one of them already has. I removed it under AC-T07-11. Restoring it is one line if you rule otherwise; the two `assertEq` lines remain the actual guard.
- All other assertions are independent. One example: C7's `assertTrue(hasAttestation(B))` is not implied by `_assertSame(latest(B), b)`, because a source could keep the record and still answer `false`.
**Where the spec was silent (PROVISIONAL):** new test name `test_ZeroSequenceIsNotAFirstAttestation`, labelled C4c; the pin's name is the Debugger's suggestion as given.
**Blocks/Unblocks:** Ready for the Debugger's full re-run, then Researcher verification.

---

### 2026-10-29 01:15 · 🧭 Researcher → ⌨️ Coder · RULING (AC-11 items 1–3)

**Context:** Round 3 verified on disk: `forge test` 7/7 with the new concrete pin running by default, interface ABI identical to the pre-D1 baseline, zero `expectRevert`, `_assertSame` confirmed to compare all four fields. AC-9, AC-10 and AC-12 are proved by mutation. Only AC-11's third item is contested.

**On Disk Now:** `test/registry/AssetRegistryInterface.t.sol` → `test_AssetTokenBoundTopicDiffersFromCompliance` now holds **two** `assertEq` lines and nothing else; the selector inequality is gone.

**Message:**

**Items 1 and 2 — ACCEPTED.** C6's `r != 1e21` was my ruling. C2's explicit `assertEq(latest(UNKNOWN).assetId, bytes32(0))` is genuinely implied: `_assertSame` compares `assetId` on its first line, so AC-7 is still met through it. Good catch, and finding one of these in your own work is the part that makes the check credible.

**Item 3 — REJECTED. Restore the line.** And the reason is that my AC-11 was imprecise, not that your reasoning was poor — the question you asked was exactly right.

You are correct that, **given the file as it stands**, the inequality is entailed: if both `assertEq`s pass, the two selectors equal two different keccak constants, so they cannot be equal. Pure logical entailment. But entailment given the current file is the wrong test, because **the test literals are not fixed — they are part of what an edit changes.**

The realistic failure path:

1. Someone renames `IAssetRegistry.AssetTokenBound` to `TokenBound(address)`, colliding with `IModularCompliance`'s.
2. The test fails, and they do the natural thing: update the literal to `keccak256("TokenBound(address)")`.
3. Now **both `assertEq`s pass** — each selector matches its own signature string honestly.
4. The removed line would fail, and **nothing else would.**

That is precisely the collision A5 exists to prevent, reachable by one rename plus the test edit that rename invites. So the line is not decoration: there is a single production-code change that makes it the only failure.

**AC-11 is therefore refined**, and this is the useful output of the exchange:

> An assertion is decoration when **no single edit to the production code can make it the only failing line**. It is *not* decoration merely because sibling assertions in the same test logically entail it while the test's own constants are held fixed — the constants are not fixed; they move with the edit.

By that test: C6's `r != 1e21` is still decoration (no rename changes `KILOBAR_FINE`'s relationship to `1e21`), C2's duplicate is still decoration (`_assertSame` compares the same field, and no edit separates them), and A5's inequality is **not**. Three applications, two removals, one restoration.

**Work:** restore `assertTrue(IAssetRegistry.AssetTokenBound.selector != IModularCompliance.TokenBound.selector);` as the third line, with a comment saying it is the guard that survives a rename-plus-literal-update, so the next person applying AC-11 does not remove it again. Then re-run and hand to the Debugger.

**Blocks/Unblocks:** Blocks the T0.7 checkmark only.

---

### 2026-10-29 · ⌨️ Coder → 🧭 Researcher · HANDOFF (round 3, item 3 restored)

**Context:** Ruling applied. A5's inequality is restored under the refined AC-11 ("decoration = no single production edit can make it the only failing line"). Uncommitted for the user's review; the rest of round 3 is already at HEAD.
**On Disk Now:** `contracts/test/registry/AssetRegistryInterface.t.sol:155-159` → `// NOT redundant, so do not remove under AC-11. If our event is renamed to collide with IModularCompliance.TokenBound and the literal above is updated to match, both assertEq lines pass honestly and this is the only line that fails. It is the guard that survives a rename plus literal update (T0.7 round-3 ruling).` then `assertTrue(IAssetRegistry.AssetTokenBound.selector != IModularCompliance.TokenBound.selector);`
**Message/Question/Finding:** `forge build` ✅ · `forge fmt --check` ✅ · `forge test` 7/7. **The ruling's scenario was proved by mutation in a scratch copy, since deleted.** The event was renamed to `TokenBound(address)`, and the test's reference and literal were updated to match. `test_AssetTokenBoundTopicDiffersFromCompliance` then fails with a bare `assertion failed`: the restored `assertTrue`, while both `assertEq` lines pass. So it is the only failing line, as the ruling says.
**Blocks/Unblocks:** Ready for the Debugger's full re-run.

---

### 2026-10-29 · ⌨️ Coder → 🧭 Researcher · HANDOFF (assertTrue message)

**Context:** One-line follow-up: the restored A5 `assertTrue` now names its defect. Uncommitted for the user's review.
**On Disk Now:** `contracts/test/registry/AssetRegistryInterface.t.sol:159-162` → `assertTrue(IAssetRegistry.AssetTokenBound.selector != IModularCompliance.TokenBound.selector, "AssetTokenBound must not share a selector with IModularCompliance.TokenBound: name-based event filtering would be ambiguous");`
**Message/Question/Finding:** `forge build` ✅ · `forge fmt --check` ✅ · `forge test` 7/7. **Noticed, not acted on (new convention):** `ReserveAttestationSourceConformance.t.sol` still has 7 message-less `assertTrue` / `assertFalse` calls, at lines 95, 100, 102, 104, 106, 143 and 176. All are `hasAttestation` checks in C2, C3, C4c and C7. The other two `assertTrue`s in the two files already carry messages. These 7 are one batch if you want them under the convention now.
**Blocks/Unblocks:** Debugger full re-run (already released).

---

### 2026-11-11 · ⌨️ Coder → 🧭 Researcher / 🐞 Debugger · HANDOFF (assertion messages)

**Context:** Applies the Researcher's YES ruling on the seven message-less `hasAttestation` checks. That ruling arrived in a direct message after the 2026-10-29 entry and is recorded here, since it never reached this thread. Fahad's instruction via the custody session: finalise T0.7. Messages only: no assertion added, removed or changed in what it tests. Uncommitted, for the user's review.
**On Disk Now:**
- `contracts/test/registry/ReserveAttestationSourceConformance.t.sol:95-97` → `assertFalse(source.hasAttestation(UNKNOWN), "C2: hasAttestation must be false for an asset that was never attested");`
- `…:150` → `assertFalse(source.hasAttestation(GOLD_LOT_001), "C4c: seq 0 must not count as a first attestation");`
- The others follow the same shape and name the required behaviour plus its conformance point. C3: "must be false before any attestation", "must be true after an accepted attestation", "must stay true after a further accepted attestation", "must stay true after a refused non-increasing seq". C7: "attesting another asset must not clear this asset's hasAttestation".
**Message/Question/Finding:** `forge build` ✅ · `forge fmt --check` ✅ · `forge test` 7/7. Every `assertTrue`/`assertFalse` in both test files now carries a message: 10/10, checked by parsing each call, because `forge fmt` wraps long calls onto several lines and a one-line grep miscounts them. `git diff HEAD` touches only the two test files. The Debugger was told directly that this file changed mid-re-run. **Not done (outside the Coder's role):** the T0.7 checkmark (Researcher only), D1, D2 and T0.8 (deferred by Fahad).
**Blocks/Unblocks:** Code-complete. Waiting on the Debugger's re-run, then a Researcher session to verify and checkmark.

---

### 2026-11-11 · 🐞 Debugger → 🧭 Researcher · REPORT (round-3 gate)

**Context:** This is the full re-run gate on T0.7 round 3, run after the Coder's 2026-11-11 message-strings batch. The method is the same as the 2026-10-28 REPORT: one configurable `MockSource` and one concrete suite subclass per mutant, all in a scratch copy of `contracts/`. Nothing in the repo was changed except the removal of one gitignored stray file (§ Process). **Verdict: THE GATE PASSES.** AC-T07-9, -10 and -12 were proved by mutation, and AC-T07-11 holds for the conformance suite. This does **not** checkmark T0.7: only the Researcher does that, and D1 (checkmark while T0.8 is impossible) is deferred to Fahad.

**On Disk Now:**
- `forge build` ✅ · `forge fmt --check` ✅ · `forge test` **7/7**. The abstract suite contributes 0 tests, as designed.
- `test/registry/ReserveAttestationSourceConformance.t.sol`: normalised against `HEAD` (whitespace collapsed, string literals blanked) it is **byte-identical**, so the batch is **message strings only**. Every `assertTrue`/`assertFalse` now carries a message, e.g. `:150` → `assertFalse(source.hasAttestation(GOLD_LOT_001), "C4c: seq 0 must not count as a first attestation");`
- `test/registry/AssetRegistryInterface.t.sol:159-162` → the restored A5 `assertTrue(… AssetTokenBound.selector != … TokenBound.selector, "AssetTokenBound must not share a selector …")`. `:167` → `test_ReserveSourceInterfaceIdIsPinned`.

**Finding — mutant × test matrix** (11 suite tests per row):

| Mutant | Result | Caught by |
| --- | --- | --- |
| correct, refuses by **revert** | 11/11 pass | — |
| correct, refuses by **silent ignore** | 11/11 pass | — |
| zeroed case echoes the queried key | 2 fail | **C2**, C4c (`assetId changed`) |
| shared record, stored `assetId` | 3 fail | **C7**, C1, C4a |
| shared record, echoes `assetId` | 2 fail | **C7** (`reserve changed`), C4a |
| shared record, per-asset seq guard | 2 fail | **C7** (`reserve changed`), C4a |
| accepts non-increasing `seq` | 2 fail | **C4b** (`reserve changed`), C4c |
| views revert on unknown key | 3 fail | **C5**, C2, C4c |
| **heartbeat** (equal seq, fresh `valuationTs`) | 1 fail | **C4b `valuationTs changed: 1761609600 != 1761609500`** → **AC-T07-9 ✅** |
| global (cross-asset) seq counter | 1 fail | **C4a** |
| accepts future `valuationTs` | 1 fail | **C8** |
| **accepts `seq = 0` first** | 1 fail | **C4c**, with message `"C4c: seq 0 must not count as a first attestation"` → **AC-T07-12 ✅** |
| C7 reachability probe | probe passes | the overwrite is still reachable (A@4 accepted), so C7 fails on isolation, not on a seq refusal |

- **AC-T07-10 ✅:** I added `submitAttestation(bytes)` to a scratch copy of the interface and ran the **default** `forge test` against the repo as it stands. Result: **6 pass / 1 fail**, `test_ReserveSourceInterfaceIdIsPinned` (`0xba66ae26…`). Inside the suite, C9 fails in all 13 concrete subclasses as well.
- **AC-T07-11 ✅ for the conformance suite.** For every remaining assertion I named a source edit that makes it the only failing line of its test. Example: a source with a global "anything attested" flag but correct records fails only C2's `assertFalse`. C2's duplicate `assetId` line and C6's `r != 1e21` are gone. The messages also make the failing line identifiable from the output, which they weren't before.

**One wording point on the refined AC-11 rule (non-blocking; the code is right).** The rule as written ("no single edit to the **production code** can make it the only failing line") does not justify the restored A5 line at `:159`. With `:153-154` pinning both selectors to fixed literals, no production-only edit can make the selectors equal without one of `:153-154` failing first. The line becomes the sole failure only when the edit **also updates the test's literal**, which is the scenario your ruling describes. The line is worth keeping (my T0.6 M4 mutant proved the same property). But the rule needs to say what it actually means, or the next person applying it will delete the line again. **Proposed wording:** *"An assertion is decoration when no edit to the production code, together with the test-literal updates a developer would make to keep the other assertions passing, can make it the only failing line."*

**Process — two items, both for the user, not the loop:**
1. **A leak from my own harness, now fixed at the source.** On 2026-10-28 my runner called `forge test --root <scratch>` from the repo root. forge writes `cache/fuzz/failures` relative to its **working directory, not `--root`**, so it created `cache/fuzz/failures/Mut07_ViewRevertUnknown/test_ViewsNeverRevert` at the **repo root**. `.gitignore` covers only `contracts/cache/`, so that file was **committed in `701ace5`**. A second copy under the ignored `contracts/cache/` has been deleted. The runner now runs forge with `cwd` inside the scratch copy, refuses a work dir inside the repo, and checks for new cache dirs after each run; today's runs left nothing behind. The committed file is inert, because forge only replays it for a contract named `Mut07_ViewRevertUnknown`, which does not exist in the repo. Removing it takes a commit: `git rm -r cache/` plus `/cache/` in `.gitignore`. That is the user's decision.
2. **`701ace5` carries more than its title says.** It is titled "docs(m3): D3 decided", but it also contains `IReserveAttestationSource.sol` (the D1 NatSpec that was "uncommitted pending the user's diff review"), the conformance suite's round-3 changes, and file 1 above. So the interface comments are **already committed**: `git diff HEAD` on that file is empty. If the diff review still matters, it now has to happen on `701ace5` itself.

**Blocks/Unblocks:** The Debugger gate on T0.7 is **passed**. It is ready for Researcher verification, then "verified, awaiting D1" per Fahad's deferral. The AC-11 wording is a convention edit, not a code change. The two process items are with the user.
