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

### 2026-10-28 11:40 PKT · ⌨️ Coder → 🐞 Debugger · HANDOFF
**Context:** [[Threads/Rounds/T2 - Researcher Rulings (round 1)|T2 rulings round 1]]: ADR 0021 mint-time freshness gate; T2.3 closed as rejected.
**On Disk Now:** `AssetLiveModule.sol` → `if (window == 0 || ts > block.timestamp || block.timestamp - ts > window) return false;` (after LIVE, before the cap) · `forge test` → `127 tests passed, 0 failed`.
**Message:** Order is LIVE → fresh → cap; every branch returns `false`. New tests: `test_MintBlockedWhenReserveStale` (τ = 1h, warp 2 days), `test_MintAllowedAtExactWindow` (age == window true, +1s false), `test_TransferAllowedWhenReserveStale`, `test_MintBlockedAfterUnfreezeUntilReattested`, `test_ShorterPerAssetWindowAppliesToMint`, `test_OwnerCanUnbindSquatterThenTokenBinds`. `bindToken` unchanged; T3's constructor will bind itself.
**Action Needed:** 🐞 Debugger re-reviews alongside T3.
**Unblocks:** T3.1

---

Up: [[Tasks/T2 - Modular Compliance]]
