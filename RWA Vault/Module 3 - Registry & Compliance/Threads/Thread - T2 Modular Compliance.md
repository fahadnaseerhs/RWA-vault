---
type: thread
task: T2
module: M3
status: active
tags: [rwa-vault, thread, m3, t2]
updated: 2026-10-28
---
# 💬 Thread — T2 Modular Compliance

> Append-only. New entries go at the **bottom**, using [[Template - Thread Entry]]. Never edit or delete an earlier entry;
> correct it with a new entry that links to it. Current state = the last entry.

**Task:** [[Tasks/T2 - Modular Compliance]] · **Spec:** [[Specs/T0.6 - IAssetRegistry Interface]] §3.3, §18.1–18.3

---

### 2026-10-28 11:05 PKT · ⌨️ Coder → 🐞 Debugger · HANDOFF
**Context:** T2.1 `ModularCompliance`, T2.2 `AssetLiveModule`, T2.4 tests; T2.3 evaluation below. Built against the real `AssetRegistry` (T4.1), not the mock.
**On Disk Now:** `contracts/src/compliance/ModularCompliance.sol` · `contracts/src/compliance/modules/AssetLiveModule.sol` · `contracts/test/compliance/{ModularCompliance,AssetLiveModule}.t.sol` · `forge test` → `79 tests passed, 0 failed` · `forge fmt --check` clean.
**Message:**
1. `AssetLiveModule.moduleCheck` returns `true` for any `from != 0`; for a mint it returns `false` (never reverts) unless the token is bound, `assetOfToken` is LIVE and `supply <= reserve && value <= reserve - supply` (overflow-safe). It relies on T3.1 calling `canTransfer` **before** `_mint` (§18.2).
2. **T2.3 evaluation — Coder recommends not using `SupplyLimitModule`.** Its cap is a per-compliance stored number that the owner would have to rewrite after every attestation through `callModuleFunction`; that is a second copy of `reserveOf` that can drift (the §18.1 / §3.3 argument), and it is not plug-and-play. The cap is enforced in `AssetLiveModule` from `registry.reserveOf` instead. 🧭 Researcher to rule.
3. `ModularCompliance`: owner immutable (ADR 0025); `bindToken` once, by owner or the token itself; 25-module cap as in T-REX; hooks are token-only; non-plug-and-play modules must return `canComplianceBind`. Custom errors are declared on the contract (the interface has none).
**Action Needed:** 🐞 Debugger reviews; 🧭 Researcher rules on item 2.
**Unblocks:** T3.1 can wire compliance.

---

### 2026-10-28 11:15 PKT · 🐞 Debugger → 🧭 Researcher, ⌨️ Coder · REPORT
**Context:** T2.1/T2.2 review of commit `5efb0a0` (T4.1 now `960b0e0`) against ADR 0014, 0019 §3/§6, 0021, 0025. Coder's run: `79 tests passed, 0 failed`. Debugger rerun not done (solc download not yet allowed).
**On Disk Now:** `contracts/src/compliance/modules/AssetLiveModule.sol:80-87` → `bytes32 assetId = registry.assetOfToken(token); if (!registry.isLive(assetId)) return false; ... return supply <= reserve && value <= reserve - supply;` · `contracts/src/registry/AssetRegistry.sol` stores no `valuationTs` after `admit`.
**Message:** Mint-only veto (§6), under-reserve cap (§3), fail-closed on unbound token, overflow-safe cap: all correct. Two findings:
1. **FAIL vs ADR 0021 (Accepted).** "A stale reserve attestation freezes minting only … one state flag and one gate on the mint path." Nothing enforces it: the registry keeps no last `valuationTs`, and `moduleCheck` allows a mint on a LIVE asset whose last attestation is days old. Repro: admit at t0 with τ = 1 h, `vm.warp(t0 + 2 days)`, mint `1` within reserve → `canTransfer` returns `true`; ADR 0021 expects `false`. The fix needs a new view on the frozen `IAssetRegistry` (e.g. `lastValuationTsOf(assetId)`) and a freshness check in `moduleCheck`, so it is routed as an **ASK**, not a mechanical fix.
2. **Front-run on `bindToken`.** `ModularCompliance.sol` `bindToken`: while `_token == 0`, any contract can call `bindToken(itself)` and take the slot; the real token's bind then reverts `TokenBindingRefused`. Effect is denial of service only (owner can `unbindToken`, and AssetLiveModule fails closed), and T-REX has the same shape. Mitigation for T5.1: bind token and compliance in the same deploy transaction, or make `bindToken` owner-only. Ruling wanted on which.
**Action Needed:** 🧭 Researcher rules on 1 (interface change + where the freshness gate lives) and 2. ⌨️ Coder implements once ruled. T2.3 (`SupplyLimitModule` not used) also awaits the Researcher.
**Unblocks:** T3.1 may wire compliance now; finding 1 must close before T7 acceptance.
### 2026-10-28 11:40 PKT · ⌨️ Coder → 🐞 Debugger · HANDOFF
**Context:** [[Threads/Rounds/T2 - Researcher Rulings (round 1)|T2 rulings round 1]]: ADR 0021 mint-time freshness gate; T2.3 closed as rejected.
**On Disk Now:** `AssetLiveModule.sol` → `if (window == 0 || ts > block.timestamp || block.timestamp - ts > window) return false;` (after LIVE, before the cap) · `forge test` → `127 tests passed, 0 failed`.
**Message:** Order is LIVE → fresh → cap; every branch returns `false`. New tests: `test_MintBlockedWhenReserveStale` (τ = 1h, warp 2 days), `test_MintAllowedAtExactWindow` (age == window true, +1s false), `test_TransferAllowedWhenReserveStale`, `test_MintBlockedAfterUnfreezeUntilReattested`, `test_ShorterPerAssetWindowAppliesToMint`, `test_OwnerCanUnbindSquatterThenTokenBinds`. `bindToken` unchanged; T3's constructor will bind itself.
**Action Needed:** 🐞 Debugger re-reviews alongside T3.
**Unblocks:** T3.1

---

### 2026-10-28 11:45 PKT · 🐞 Debugger → 🧭 Researcher · REPORT
**Context:** Re-review of `65a55d2` against the T2 round-1 rulings (ADR 0021 gate).
**On Disk Now:** `contracts/src/compliance/modules/AssetLiveModule.sol` → `if (window == 0 || ts > block.timestamp || block.timestamp - ts > window) return false;` placed after the LIVE check and before the cap · tests `test_MintBlockedWhenReserveStale` (τ 1 h, warp 2 days), `test_MintAllowedAtExactWindow`.
**Message:** **PASS.** Order LIVE → fresh → cap, returns `false`, never reverts, age == window passes, future timestamp fails closed. Finding 1 from 11:15 closed. Finding 2 (bindToken) closed by ruling: Token binds itself in its constructor; T5.1 asserts `getTokenBound() == token`.
**Action Needed:** 🧭 Researcher may VERIFY T2.1–T2.4 once forge is rerun independently.
**Unblocks:** T3.1

---

### 2026-10-28 15:20 PKT · 🧭 Researcher → ⌨️ Coder, 🐞 Debugger · VERIFY ✅
**Context:** T2.1, T2.2 and T2.4 against [[Threads/Rounds/T2 - Researcher Rulings (round 1)|T2 rulings]] at `0749e04`. Debugger rerun `194 passed`.
**On Disk Now:** `src/compliance/modules/AssetLiveModule.sol` → `if (window == 0 || ts > block.timestamp || block.timestamp - ts > window) return false;` placed after `isLive` and before the cap.
**Message:** Order is LIVE, then fresh, then cap. It returns `false` and never reverts. Transfers and burns pass (ADR 0019 §6, ADR 0021). All four ruling tests and `test_OwnerCanUnbindSquatterThenTokenBinds` are present. T2.3 was closed earlier by ruling.
**Action Needed:** none. T2 ticked.
**Unblocks:** nothing new

---

Up: [[Tasks/T2 - Modular Compliance]]
