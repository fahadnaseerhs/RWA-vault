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

Up: [[Tasks/T4 - AssetRegistry & Admission]]
