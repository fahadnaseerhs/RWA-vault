---
type: thread
task: T4
module: M3
status: active
tags: [rwa-vault, thread, m3, t4]
updated: 2026-10-28
---
# 💬 Thread — T4 AssetRegistry & Admission

> Append-only. New entries go at the **bottom**, using [[Template - Thread Entry]]. Never edit or delete an earlier entry;
> correct it with a new entry that links to it. Current state = the last entry.

**Task:** [[Tasks/T4 - AssetRegistry & Admission]] · **Spec:** [[Specs/T0.6 - IAssetRegistry Interface]]

---

### 2026-10-28 10:55 PKT · ⌨️ Coder → 🐞 Debugger · HANDOFF
**Context:** T4.1 state machine, with the T4.2 clauses 2–4 and T4.6 transition tests it needs to be testable. Built against the frozen `IAssetRegistry`, ADR 0019 and Q13/Q14/Q15/Q17.
**On Disk Now:** `contracts/src/registry/AssetRegistry.sol` · `contracts/test/registry/AssetRegistry.t.sol` · `forge test` → `48 tests passed, 0 failed` (42 new + 6 interface) · `forge fmt --check` clean.
**Message:** Check order in `admit`: state → source/`NoAttestation` → `AssetIdMismatch` → clause 2 → clause 3 (PENDING only) → `ValuationInFuture` → `ValuationStale`. Window 0 rejects every admission. Coder readings for the Researcher to confirm:
1. Re-attestation below current supply is **accepted** with `UnderReserve` (ADR 0019 §3, Q14=B). The `ReserveTooLow` natspec says "against current supply on re-attestation", which contradicts the ADR; I followed the ADR.
2. Re-attestation of a LIVE asset with no token bound treats supply as 0 instead of reverting `TokenNotBound`.
3. `register` does not check `assetId == keccak256(bytes(assetRef))`; the interface has no error for it.
4. Constructor rejects a zero owner with `NotOwner(address(0))`; owner is `immutable` (ADR 0025).
5. `admit` on FROZEN reverts `AssetNotLive`; a frozen asset cannot be re-attested until unfrozen.
**Action Needed:** 🐞 Debugger reviews; 🧭 Researcher rules on 1–5. T4.3 (MS1 source) and T4.5 (invariant through the token) wait for T3.
**Unblocks:** T2.2 can bind to the real registry.

---

### 2026-10-28 11:10 PKT · 🐞 Debugger → ⌨️ Coder, 🧭 Researcher · REPORT
**Context:** T4.1 review of commit `21e3091` against `IAssetRegistry`, ADR 0018, ADR 0019 §1–§6, ADR 0025, Q17.
**On Disk Now:** `contracts/src/registry/AssetRegistry.sol:153` → `if (s == AssetState.PENDING && a.reserve < intendedSupply) revert ReserveTooLow(...)` · `:177` → `uint256 supply = token == address(0) ? 0 : IERC20(token).totalSupply();` · Coder's run: `48 tests passed, 0 failed`. **Debugger rerun not done:** solc 0.8.26 download not yet allowed in the Debugger's environment.
**Message:** Code review **PASS, no mechanical bugs found**. Check order, revert-writes-nothing (§1), LIVE re-attestation (§2), under-reserve accept + `UnderReserve` (§3), freeze agent / unfreeze owner (§4), `AssetIdMismatch` (§5), immutable owner and no proxy (ADR 0025) all match. Tests cover each revert with `_expectPendingUntouched()`, the τ boundary, fuzz on clauses 2 and 4.
Added to the Coder's five readings for the 🧭 Researcher:
6. `setAttestationSource` can swap sources while `_lastSeq` stays. A new source whose sequence starts at or below the old one makes every `admit` revert `StaleSequence` forever. Is that intended (source swap = new sequence must continue), or should a swap reset nothing and be documented?
Test gaps for ⌨️ Coder (non-blocking): no test for reading 2 (LIVE re-attestation with no token bound, supply treated as 0); no `expectEmit` on `AssetAdmitted` for first admission.
Carry to T5.1: the deploy script must call `setValuationWindow(24 hours)` (ADR 0018). Until it does, the window is 0 and every admission fails closed.
**Action Needed:** 🧭 Researcher rules on readings 1–6. ⌨️ Coder adds the two tests when convenient. 🐞 Debugger reruns `forge test` once solc is available.
**Unblocks:** T2.2 may bind to `AssetRegistry` at `21e3091`.
### 2026-10-28 11:40 PKT · ⌨️ Coder → 🐞 Debugger · HANDOFF
**Context:** [[Threads/Rounds/T4 - Researcher Rulings (round 1)|T4 rulings round 1]] changes (a)–(d) and T4.3.
**On Disk Now:** `IAssetRegistry.sol` → `error AssetRefMismatch(bytes32 assetId, bytes32 expected);` · `function valuationTsOf(bytes32 assetId) external view returns (uint64);` · `src/registry/CustodianAttestationSource.sol` (no `AssetRegistry` import) · `forge test` → `127 tests passed, 0 failed`.
**Message:** (a) `ReserveTooLow` NatSpec now says first admission only. (b) `valuationTsOf` stored in `admit`. (c) `register` reverts `EmptyAssetId` on an empty ref and `AssetRefMismatch` on a slug/id mismatch. (d) `setAttestationSource` NatSpec documents that `lastSeq` survives a swap. Reading 2 comment added. Selector-distinctness test now covers 23 errors. T4.3 built to spec: submitter allow-list, `submitAttestation(att, envelopeHash)`, `SequenceNotIncreasing`, zero reserve accepted, integration test submit → admit → LIVE. New tests: `test_RegisterRejectsSlugMismatch`, `test_RegisterRejectsEmptyRef`, `test_ValuationTsOfRecordsAdmitted`, `test_SourceSwapKeepsLastSeq`, plus `CustodianAttestationSource.t.sol` (7).
**Action Needed:** 🐞 Debugger re-reviews; 🧭 Researcher verifies T4.1–T4.3 acceptance.
**Unblocks:** T5.1 can deploy the MS1 source.

---

### 2026-10-28 11:45 PKT · 🐞 Debugger → 🧭 Researcher · REPORT
**Context:** Re-review of `65a55d2` (T4 round-1 rulings) and first review of T4.3. Coder's run: `127 tests passed, 0 failed`. Debugger rerun still pending solc.
**On Disk Now:** `contracts/src/registry/AssetRegistry.sol` → `_valuationTs[assetId] = a.valuationTs;` in `admit`; `register` → `if (assetId != expected) revert AssetRefMismatch(assetId, expected);` · `contracts/src/registry/CustodianAttestationSource.sol` → `submitAttestation(att, envelopeHash)`: submitter-only, non-zero `assetId` and `envelopeHash`, strictly increasing `seq`, emits `AttestationSubmitted(..., envelopeHash, submitter)`.
**Message:** **PASS.** Rulings applied as written. T4.3 matches ADR 0027 (no on-chain signature check, envelope hash recorded for M9, no clause 2–4 judgement, one-way seam per ADR 0017, immutable owner).
**Action Needed:** 🧭 Researcher may VERIFY T4.1–T4.3 once forge is rerun independently.
**Unblocks:** T3, T5.1

---

### 2026-10-28 11:10 PKT (06:10 UTC) · 🐞 Debugger → 🧭 Researcher · REPORT
**Context:** Independent forge rerun of T1, T2 and T4 code at `65a55d2` (solc 0.8.26 and 0.8.17 from the Solidity GitHub releases, Fahad approved).
**On Disk Now:** `FOUNDRY_OFFLINE=true forge test` → `Ran 6 test suites: 127 tests passed, 0 failed, 0 skipped` · `forge fmt --check` clean · `forge build --force` → compiles; lint warnings only: `block-timestamp` at `AssetLiveModule.sol:85` (intended, ADR 0021 gate) and `erc20-unchecked-transfer` ×4 in `test/registry/ERC3643Acceptance.t.sol` (test-only).
**Message:** The Coder's 127/127 is reproduced. T1, T2 and T4.1–T4.3 are green and reviewed.
**Action Needed:** 🧭 Researcher may VERIFY T1, T2 and T4.1–T4.3.
**Unblocks:** Researcher VERIFY

---

Up: [[Tasks/T4 - AssetRegistry & Admission]]
