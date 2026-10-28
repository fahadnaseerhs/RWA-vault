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

### 2026-10-28 11:20 PKT (06:20 UTC) · 🐞 Debugger → 🧭 Researcher, ⌨️ Coder · REPORT
**Context:** T3 Token + T4.5 invariant review of `f648f46` (head `2087fcd`, includes T1 alignment `b2e66ae`), against the T3 build spec, ADR 0015, 0019 §3/§6, 0021, 0025.
**On Disk Now:** Debugger rerun `FOUNDRY_OFFLINE=true forge test` → `Ran 10 test suites: 188 tests passed, 0 failed, 0 skipped` · invariants `invariant_noMintBeyondReserve`, `invariant_noMintWhileNotLiveOrStale`, `invariant_supplyLeReserveWithoutDownwardAttestation` → `runs: 256, calls: 128000` · `forge fmt --check` clean · `src/tokens/Token.sol:213` → `if (!_compliance.canTransfer(address(0), to, amount)) revert TransferNotCompliant(...)` before `_mint` at `:214`.
**Message:** **PASS.** Mint order isVerified → canTransfer → `_mint` → `created` (§18.2). Holder-transfer checks in spec §3 order inside `_update`; mint/burn not paused (T-REX). Forced transfer is owner-only, timelocked, receiver-verified, releases the frozen shortfall. Constructor binds compliance (closes T2 finding 2). Token has no registry/asset coupling. Invariant is "no mint beyond reserve", per the Researcher's §7 restatement. Invariant suite sits in `test/invariant/`, so the CI invariants job will pick it up.
**Carry to T5.1** (wiring checks the deploy script must make, all seen only in `test/helpers/M3System.sol` so far):
1. `setValuationWindow(24 hours)` (ADR 0018).
2. Add `KYC_TOPIC` to ClaimTopicsRegistry; assert `getClaimTopics().length > 0`.
3. `compliance.getTokenBound() == token`.
4. `identityRegistry.addAgent(token)`, or `recoveryAddress` reverts on `registerIdentity`/`deleteIdentity`.
5. AssetLiveModule added to compliance; `assetRegistry.setTokenFor`; `setAttestationSource`; `unpause` last.
**Action Needed:** 🧭 Researcher may VERIFY T3 and T4.5. ⌨️ Coder covers 1–5 in T5.1.
**Unblocks:** T5.1

---

### 2026-10-28 15:20 PKT · 🧭 Researcher → ⌨️ Coder, 🐞 Debugger · VERIFY ✅ (T3.1, T3.2, T3.4, T3.6) · RULING (item 5) · one fix before T3.3 is ticked
**Context:** T3 against [[Specs/T3 - ERC-3643 Token Build Spec|T3 spec §9]] at `0749e04`. Debugger rerun `188/194 passed`.
**On Disk Now:** `src/tokens/Token.sol:319` → `if (!_identityRegistry.contains(newWallet)) {` then `registerIdentity(...)`. When it is false, nothing checks **whose** identity `newWallet` already holds.
**Message:**
1. AC-T3-1 ✅ (the six inherited tests run unchanged on the real suite, and every §8 name is present) · AC-T3-2 ✅ (no asset or registry reference in `Token.sol`, by grep) · AC-T3-3 ✅ · AC-T3-4 ✅.
2. **RULING item 5(a): change needed.** If `newWallet` is already registered, it must be registered **to `investorOnchainID`**. Otherwise revert `RecoveryIdentityMismatch(newWallet, investorOnchainID)` before any balance moves. Today, a wallet registered to investor B that also holds a management key on investor A's ONCHAINID would receive A's tokens while staying B's in the registry, so the holdings and the identity disagree. Test: `test_RecoveryRejectsNewWalletOfOtherIdentity`.
3. 5(b) confirmed (the unfreeze and freeze event pair). 5(c) confirmed (unbind the old compliance, bind the new, as T-REX does). 5(d) confirmed: `forcedTransferEta` is a read-only view, so ADR 0015's "no new owner powers" is not affected.
**Action Needed:** ⌨️ Coder applies 2. 🐞 Debugger re-checks. 🧭 Researcher then ticks T3.3.
**Unblocks:** T3.3

---

### 2026-10-28 15:40 PKT · ⌨️ Coder → 🐞 Debugger · HANDOFF
**Context:** Researcher RULING item 5(a) on T3.3 (entry above).
**On Disk Now:** `src/tokens/Token.sol` `recoveryAddress` → `if (_identityRegistry.contains(newWallet) && address(_identityRegistry.identity(newWallet)) != investorOnchainID) revert RecoveryIdentityMismatch(newWallet, investorOnchainID);` placed before the balance read, so nothing moves · `test/tokens/Token.t.sol` → `test_RecoveryRejectsNewWalletOfOtherIdentity` (balances and registry unchanged after the revert) · `forge test` → `195 tests passed, 0 failed` · `forge fmt --check` clean.
**Message:** Only the guard is new; the register-if-absent path is unchanged, so a new wallet already registered to the same investor still recovers without a second `registerIdentity`.
**Action Needed:** 🐞 Debugger re-checks. 🧭 Researcher ticks T3.3.
**Unblocks:** T3.3

---

Up: [[Tasks/T3 - ERC-3643 Token]]
