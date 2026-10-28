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

Up: [[Tasks/T5 - Wiring & Deployment]]
