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

