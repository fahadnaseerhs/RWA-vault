---
type: thread
task: T3
module: M3
status: active
tags: [rwa-vault, thread, m3, t3]
updated: 2026-10-28
---
# 💬 Thread — T3 ERC-3643 Token

> Append-only. New entries go at the **bottom**, using [[Template - Thread Entry]]. Never edit or delete an earlier entry;
> correct it with a new entry that links to it. Current state = the last entry.

**Task:** [[Tasks/T3 - ERC-3643 Token]] · **Spec:** [[Specs/T3 - ERC-3643 Token Build Spec]]

---

### 2026-10-28 12:15 PKT · ⌨️ Coder → 🐞 Debugger · HANDOFF
**Context:** T3.1–T3.4, T3.6 and T4.5 per the T3 build spec. T3.5 stays deferred.
**On Disk Now:** `contracts/src/tokens/Token.sol` · `test/helpers/M3System.sol` (T5.1-order builder) · `test/tokens/{Token.t.sol,ERC3643AcceptanceImpl.t.sol}` · `test/invariant/AttestedSupplyLeReserve.t.sol` · `forge test` → `188 tests passed, 0 failed` · invariants `runs: 256, calls: 128000` each · `forge fmt --check` clean.
**Message:**
1. `mint`: `isVerified` → `canTransfer(0, to, amount)` → `_mint` → `created`. `test_MintOrderComplianceBeforeMint` mints to `reserve − 5`, then `reserve − supply + 1` reverts and `reserve − supply` succeeds.
2. Holder transfers are checked in `_update` in the §3 order. Mint, burn, forced moves and recovery set their own rules; a private `_forcing` flag makes `_update` skip holder checks only during a forced move or a recovery.
3. The six inherited acceptance tests pass **unchanged** on the real suite (T1 + T2 + T4 + T4.3 + Token).
4. AC-T3-2: `grep "IAssetRegistry\|assetId\|AssetLiveModule" Token.sol` → 0 matches. AC-T3-4: no `Ownable`/`AccessControl` import.
5. Coder choices for the Researcher to confirm: (a) `recoveryAddress` registers the new wallet only if it is not already in the registry, then deletes the lost one; (b) a carried-over partial freeze emits `TokensUnfrozen(lost)` + `TokensFrozen(new)`; (c) `setCompliance` unbinds the old compliance before binding the new one (T-REX); (d) `forcedTransferEta(from,to,amount)` is an extra view for the console.
**Action Needed:** 🐞 Debugger reviews; 🧭 Researcher verifies AC-T3-1…4 and rules on 5.
**Unblocks:** T5.1

---

Up: [[Tasks/T3 - ERC-3643 Token]]
