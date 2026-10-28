---
type: thread
task: T5
module: M3
status: active
tags: [rwa-vault, thread, m3, t5]
updated: 2026-10-28
---
# 💬 Thread — T5 Wiring & Deployment

> Append-only. New entries go at the **bottom**, using [[Template - Thread Entry]]. Never edit or delete an earlier entry;
> correct it with a new entry that links to it. Current state = the last entry.

**Task:** [[Tasks/T5 - Wiring & Deployment]] · **Spec:** [[Specs/T5.1 - Deploy Script Spec]]

---

### 2026-10-28 12:35 PKT · ⌨️ Coder → 🐞 Debugger · HANDOFF
**Context:** T5.1 `DeployM3.s.sol` per the T5.1 spec, plus the `smoke()` path the spec assigns to T5.3.
**On Disk Now:** `contracts/script/DeployM3.s.sol` · `contracts/test/script/DeployM3.t.sol` · `foundry.toml` → `{ access = "read-write", path = "./deployments" }` · `.gitignore` → `contracts/deployments/31337.json` · `forge test` → `194 tests passed, 0 failed`.
**Message:**
1. **AC-T5-1, on a real anvil:** `forge script script/DeployM3.s.sol --rpc-url local --broadcast` → `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.`; `cast call <token> compliance()` = `0xC6bA…EdD2` = file `.compliance`; `cast call <assetRegistry> attestationSource()` = `0x59F2…d8d0` = file `.attestationSource`; `paused()` = `false`. `--sig "smoke()"` → `SMOKE OK: FIXTURE lot LIVE, supply 999900000000000000000`.
2. AC-T5-2/3: `test_SmokeOnboardsFixtureLot`, `test_WiringCheckCatchesSquattedCompliance` (owner unbinds, squatter binds → `WiringMismatch("compliance.token")`), `test_WiringCheckCatchesPausedToken`, `test_RejectsEoaOwnerOffAnvil`, `test_SmokeIsLocalOnly`.
3. AC-T5-4: `grep -rn "PRIVATE_KEY\|0x[0-9a-f]\{64\}" contracts/script` → no match. Test keys are the public anvil keys and live in `test/` only.
4. AC-T5-5: How to Run §2, §3, §4 and §6 rewritten to the real commands and env names.
5. Debugger carries covered: τ from `M3_VALUATION_WINDOW` (default 86400, checked `registry.window`); `KYC_TOPIC` seeded and `topics.kycOnly` asserted; `compliance.token` asserted; `ir.tokenAgent` granted and asserted; module bound; source set; unpause last. `setTokenFor` is at onboarding (spec §3).
6. Coder choices: the agent key pays for every constructor; `KeyMismatch(role, expected, fromKey)` when an env address and its key disagree; `gitCommit` comes from `GIT_COMMIT` (no ffi), default `"unknown"`. The deployment file is not read back in the in-process tests, because parallel tests share it; AC-T5-1 covers it on anvil.
**Action Needed:** 🐞 Debugger reviews; 🧭 Researcher verifies AC-T5-1…5.
**Unblocks:** T6.1a (reads `deployments/<chainid>.json`), T5.2 (real multisig), T5.3

---

### 2026-10-28 14:55 PKT · 🐞 Debugger → 🧭 Researcher · REPORT
**Context:** T5.1 `DeployM3` review of `13f1888` (head `d1fd520`) against the T5.1 spec and the five T3 carries.
**On Disk Now:** Debugger rerun `FOUNDRY_OFFLINE=true forge test` → `Ran 11 test suites: 194 tests passed, 0 failed, 0 skipped` · `forge fmt --check` clean · on a fresh `anvil`: `forge script script/DeployM3.s.sol --rpc-url local --broadcast` → `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.`, writes `deployments/31337.json`; `--sig "smoke()"` → `SMOKE OK: FIXTURE lot LIVE, supply 999900000000000000000` (999.9e18, ADR 0020).
**Message:** **PASS.** `verifyWiring` asserts all five carries: window (`registry.window`, default 86400 per ADR 0018), KYC-only topic list, `compliance.token`, `ir.tokenAgent`, module bound, source set, owner on all eight contracts, `!paused` last. A non-anvil chain refuses an EOA owner (`OwnerMustBeContract`, ADR 0015). `setTokenFor` happens at onboarding per spec §3.
**Action Needed:** 🧭 Researcher may VERIFY T5.1. Next for 🐞 Debugger: T6.1a, T6.3, T6.1b.
**Unblocks:** T6.1a

---

### 2026-10-28 15:20 PKT · 🧭 Researcher → ⌨️ Coder, 🐞 Debugger · VERIFY ✅ (T5.1) · RULING (item 6)
**Context:** T5.1 against [[Specs/T5.1 - Deploy Script Spec|T5.1 spec §6]] at `0749e04`. AC-T5-1 was run on a real anvil by both the Coder and the Debugger (14:55).
**On Disk Now:** `Running/How to Run Module 3.md` §6 → `forge script script/DeployM3.s.sol --rpc-url local --broadcast`, with every `M3_*` variable the script reads (checked by grep: `M3_OWNER[_PK]`, `M3_AGENT[_PK]`, `M3_KYC_ISSUER_KEY/_PK`, `M3_ASSET_REF`, `M3_TOKEN_NAME/SYMBOL`, `M3_VALUATION_WINDOW`, `M3_IDENTITY_STORAGE`).
**Message:**
1. AC-T5-1 ✅ · AC-T5-2 ✅ · AC-T5-3 ✅ · AC-T5-4 ✅ · AC-T5-5 ✅. **AC-T5-6 and AC-T5-7 (`VerifyWallet.s.sol`) were added to the spec after this build. They move to the T6.1a batch** and are not part of this tick.
2. **RULING item 6: all three confirmed.** Agent-paid constructors are fine, because constructors grant no power and the owner is an argument. `KeyMismatch(role, expected, fromKey)` is good, since it catches the one misconfiguration a human makes. `GIT_COMMIT` from env, default `"unknown"`, with no FFI, is right.
**Action Needed:** none for T5.1. T5.1 ticked. T5.2 (multisig) and T5.3 are next on the board.
**Unblocks:** T6.1a

---

### 2026-10-28 15:30 PKT · ⌨️ Coder → 🐞 Debugger · HANDOFF
**Context:** [[Specs/T5.1 - Deploy Script Spec|T5.1 §7]] devnet KYC helper, built with T6.1a.
**On Disk Now:** `contracts/script/VerifyWallet.s.sol` → `run(address wallet, uint16 country)`, `verify(...)` public · `test/script/DeployM3.t.sol` → `test_VerifyWalletMakesWalletVerified`, `test_VerifyWalletDevnetOnly` (AC-T5-6, both `verify` and `run` revert `VerifyWalletDevnetOnly()` on 421614), `test_VerifyWalletRejectsWrongWalletKey` · `forge test` → `221 tests passed, 0 failed` · on anvil: `VERIFIED wallet 0x90F79bf6EB2c4f870365E785982E1f101E93b906`.
**Message:** Steps 1–5 as written; the claim goes through `identity.execute` from the wallet. AC-T5-7: How to Run §6 gives the one-line command. See [[Threads/Thread - T6.1a Onboarding Command]] reading 5 on the §7 wording.
**Action Needed:** 🐞 Debugger reviews; 🧭 Researcher verifies AC-T5-6/7.
**Unblocks:** T6.2 S4

---

Up: [[Tasks/T5 - Wiring & Deployment]]
