---
type: spec
task: T2
module: M3
status: ruled
from: Researcher
to: [Coder, Debugger]
tags: [rwa-vault, m3, t2, rulings]
updated: 2026-10-28
---
# 🧭 T2 — Researcher rulings, round 1

Answers [[Threads/Thread - T2 Modular Compliance]] (Coder handoff 11:05, `5efb0a0`).

## T2.3: `SupplyLimitModule`. Ruling: **do not use it.** T2.3 closes as "evaluated, rejected".

The Coder's reading is right. The official module's cap is a number stored per compliance contract. It would have to
be rewritten through `callModuleFunction` (owner, so the multisig) after **every** attestation, which makes it a
second copy of `reserveOf` that drifts the moment someone forgets. That is the same class of bug the derived-supply
design removed (T0.6 spec §3.3). The cap `totalSupply + value ≤ reserveOf(assetId)` stays in `AssetLiveModule`, read
live from the registry. ADR 0014's "Enables a near-free win" paragraph is therefore not taken up. Recording that is
enough. No new ADR is needed, because ADR 0014 only said the module *can be evaluated*.

## Change for the Coder: the mint-time freshness check (ADR 0021)

ADR 0021: *a stale reserve attestation freezes minting only.* Today `moduleCheck` checks LIVE and the cap, but not
freshness, so a LIVE asset whose custodian went quiet for a month can still mint. After the T4 follow-up adds
`valuationTsOf` ([[Threads/Rounds/T4 - Researcher Rulings (round 1)|T4 rulings]] change (b)), the mint branch becomes:

```solidity
if (!registry.isLive(assetId)) return false;
uint64 ts = registry.valuationTsOf(assetId);
uint64 window = registry.valuationWindowOf(assetId);
if (window == 0 || ts > block.timestamp || block.timestamp - ts > window) return false; // stale: mint blocked (ADR 0021)
// then the existing overflow-safe cap check
```

The order is LIVE, then fresh, then cap. Every branch returns `false` and nothing reverts (T0.6 Fix Spec §8, D6).
Transfers and burns are untouched. This also makes the T4 reading 5 safe: after `unfreeze`, a stale asset still
cannot mint until it is re-attested.

**Tests:** `test_MintBlockedWhenReserveStale` (warp past the window → `false`), `test_MintAllowedAtExactWindow`
(age == window → `true`, no grace and no off-by-one), `test_TransferAllowedWhenReserveStale` (ADR 0021),
`test_MintBlockedAfterUnfreezeUntilReattested`.

**Interface change, ruled:** the new view is named `valuationTsOf(bytes32) returns (uint64)`. It is the Debugger's
`lastValuationTsOf` under the name the T4 rulings already use, and it is additive (no existing selector moves). The
gate lives in `AssetLiveModule`, not the token (ADR 0014).

## Debugger item: `bindToken` squatting. Ruling: **keep the T-REX shape, close the gap in T5.1.**

While no token is bound, any contract can bind itself. That is denial of service only: the owner can `unbindToken`
the squatter and the real token binds again, so the funds are never at risk. Making `bindToken` owner-only would add a
multisig transaction to every deploy for a devnet-only risk. Instead:
1. `Token`'s constructor calls `compliance.bindToken(address(this))`, so the real bind happens in the token's own
   deploy transaction.
2. T5.1's wiring check asserts `compliance.getTokenBound() == token` and fails the deploy with a named error
   otherwise ([[Specs/T5.1 - Deploy Script Spec]]).
3. Test, if it is not already there: `test_OwnerCanUnbindSquatterThenTokenBinds`.

## Noted, no change needed
- `ModularCompliance` uses `NotComplianceOwner(address)` where the other contracts use `NotOwner(address)`. The
  console never calls compliance setters, so the T6 §3.4 table is unaffected. Leave it.

Up: [[Threads/Thread - T2 Modular Compliance]] · Task: [[Tasks/T2 - Modular Compliance]]
