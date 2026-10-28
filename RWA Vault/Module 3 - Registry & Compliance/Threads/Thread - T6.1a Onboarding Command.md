---
type: thread
task: T6.1a
module: M3
status: active
tags: [rwa-vault, thread, m3, t6]
updated: 2026-10-28
---
# 💬 Thread — T6.1a Onboarding Command

> Append-only. New entries go at the **bottom**, using [[Template - Thread Entry]]. Never edit or delete an earlier entry;
> correct it with a new entry that links to it. Current state = the last entry.

**Task:** [[Tasks/T6 - Provider Onboarding Console]] · **Spec:** [[Specs/T6.1a - Onboarding Script Spec]]

---

### 2026-10-28 15:30 PKT · ⌨️ Coder → 🐞 Debugger, 🧭 Researcher · HANDOFF
**Context:** T6.1a built to [[Specs/T6.1a - Onboarding Script Spec]] §1–§4, plus `VerifyWallet.s.sol` (T5.1 §7).
**On Disk Now:** `contracts/script/OnboardAsset.s.sol` · `contracts/script/VerifyWallet.s.sol` · `scripts/onboard/{lib,run,make-fixture-attestation,build-addon}.mjs` · `contracts/test/registry/OnboardAsset.t.sol` (23) · `scripts/onboard/onboard.test.mjs` (11) · `contracts/script/input/{custodian.mldsa65.pub,custodian.json,gold-lot-002.json,gold-lot-002.seq1.att.json}` · golden vector `GOLD_LOT_001_METADATA_HASH = 0x3312ef45…deedd7` in `packages/types/src/__tests__/fixtures.ts` (also equals `cast keccak $(cast abi-encode …)`) · `forge test` → `221 tests passed, 0 failed` · `pnpm test:onboard` → `pass 11, fail 0` · `forge fmt --check` and prettier clean · AC-25: `grep -n ffi contracts/foundry.toml contracts/script/OnboardAsset.s.sol` → no match.
**Message:** AC-24 run on a fresh anvil: `DeployM3` → `VerifyWallet` (anvil account 3) → `pnpm m3:fixture-attestation --asset gold-lot-002 … --ts now` → `pnpm m3:onboard contracts/script/input/gold-lot-002.json --broadcast` ended `state LIVE`, `reserveOf 999900000000000000000`, `totalSupply 999900000000000000000`, five tx hashes (register, setTokenFor, submitAttestation, admit, mint). `cast call` agrees: `stateOf = 2`, reserve, supply and provider balance all `999900000000000000000`. Second run: `already live`, `transactions: none sent by this run`, exit 0. An unverified provider printed the §3 P6 sentence, `ProviderNotVerified(0x9965…A4dc)`, exit 4. Coder readings for the 🧭 Researcher:
1. **StaleSequence is only reachable at the source.** A PENDING asset always has `lastSequenceOf == 0` and the source refuses `seq ≤ latest`, so the reachable case is "the source already holds this seq or newer from another envelope". The script raises `AdmitRejected(StaleSequence(seq, onSourceSeq), "<§3.4 sentence> The source already holds a newer attestation (seq M).")`, which joins the spec's two sentences. The registry-side precheck is kept for completeness.
2. **Admission errors wrap the registry error:** `AdmitRejected(bytes reason, string sentence)`. Tests assert the inner selector and arguments **and** the exact sentence. The unknown-selector path prints the hex and "unexpected; report it".
3. **Exit code 4 added.** forge 1.7.1 exits **0** when a script reverts, so `run.mjs` treats a missing `ONBOARD_STATUS=` line as failure (exit 4). Exits 1/2/3 are as in the spec.
4. **A failed pre-check sends nothing at all, `register` included**, because forge simulates the whole script before broadcasting. Re-running continues as §3 S says.
5. **VerifyWallet adds the claim through `execute`, as §7 says.** In onchain-id 2.2.1 a management key also passes `onlyClaimKey` (`keyHasPurpose` returns true for purpose 1), so a direct `addClaim` from the wallet would not revert (`DeployM3.smoke` does that). This is a wording fix to §7, not a behaviour change.
6. **M1 finding, not fixed here:** `packages/pq-core/src/native.ts` calls `require(...)` inside an ESM package, where `require` is undefined. Stage 1 loads the same napi addon with `createRequire`. `pnpm pq:addon` builds it to `packages/pq-core/pq-core.node` (gitignored).
7. The verified file also carries `chainId` and `assetRef`, so forge checks `AttestationForOtherChain` / `VerifiedFileForOtherAsset` itself. Extra named errors: `TokenBoundToOtherAsset`, `CustodianKeyMismatch`, `MalformedAttestation` (unknown envelope fields such as `publicKey` are rejected).
8. New root devDependencies: `viem` 2.21.0 (pinned; T6.1b will use the same) and `@rwa-vault/types` (workspace).
9. The devnet custodian **public** key and the example envelope are committed; the private key stays in `contracts/.onboard/keys/` (gitignored). Regenerating the key rewrites the committed public key, which is expected on devnet.
**Action Needed:** 🐞 Debugger reviews (rerun needs `pnpm install`, `pnpm --filter @rwa-vault/types build`, `pnpm pq:addon`). 🧭 Researcher rules on 1–9 and verifies AC-4…8, AC-19…26 and T4.4 (§2.3).
**Unblocks:** T6.3, T6.2 rehearsal (How to Run §6/§7 now give the four AC-24 commands)

---

### 2026-10-28 15:50 PKT · 🧭 Researcher → ⌨️ Coder, 🐞 Debugger · RULING (readings 1–9) · T6.3 scope
**Context:** Coder handoff 15:30 (`ed89bbe`). **VERIFY of T6.1a waits for the 🐞 Debugger's review**, per the loop. These rulings come first so the review has the intended behaviour.
**On Disk Now:** `contracts/script/OnboardAsset.s.sol` · `scripts/onboard/run.mjs` · Coder's results: `forge test` 221/221, `pnpm test:onboard` 11/11, AC-24 run on a fresh anvil.
**Message:**
1. **Confirmed.** For a PENDING asset, clause 2 can only fail at the source, and the joined sentence is right. Keep the registry pre-check: it costs nothing, and it is what fires once M5 replaces the source.
2. **Confirmed.** `AdmitRejected(bytes reason, string sentence)` keeps the exact registry error inspectable, which satisfies AC-5 (selector plus sentence).
3. **Confirmed, and it is required, not optional.** A green exit on a failed onboarding would make T6.2 lie. Add one test asserting that a revert gives a non-zero exit (`test_RunExitsNonZeroOnScriptRevert`) if it is not already covered by the 11.
4. **Confirmed.** All-or-nothing simulation is stronger than the spec asked. AC-7's "no broadcast" holds trivially.
5. **Confirmed, and my spec wording was wrong.** In 2.2.1 a management key does pass `onlyClaimKey`. Using `execute` stays, because it is the path that also works when the wallet holds only purpose 1 in a later upstream. I've corrected the T5.1 §7 wording. Together with the 15:20 T1 note, this means any management key on the KYC issuer can sign claims, which is a T5.2 runbook item.
6. **Logged as an M1 defect, not fixed here** (right call: M1 code is outside M3's scope). Recorded in the M1 task list for its owner. Stage 1's `createRequire` workaround is acceptable until M1 fixes it.
7. **Confirmed.** Extra named errors that close a check are welcome. `MalformedAttestation` rejecting a `publicKey` field is exactly the §2.2 rule.
8. **Confirmed.** `viem` pinned at 2.21.0 matches ADR 0026's stack.
9. **Confirmed.** A devnet public key and an example envelope in git are fine. The private key must never be committed. Add `contracts/.onboard/` to the AC-T5-4 key grep's scope in your next touch.
**T6.3 scope (no separate spec needed):** T6 spec AC-17 **as corrected by [[Specs/T3 - ERC-3643 Token Build Spec|T3 spec §10]]**, so `test_DirectTransferToUnverifiedReverts` and `test_DirectMintToUnverifiedReverts` → `ReceiverNotVerified`, `test_DirectMintWhenAssetNotLiveReverts` → `TransferNotCompliant(address(0), to, amount)`, and `test_DirectTransferWhenAssetFrozenSucceeds`. Add `test_DirectMintWhenReserveStaleReverts` (ADR 0021) and `test_DirectMintBeyondReserveReverts`, because "bypass" means each gate the console checks must also hold when someone calls the contract directly. Build the suite with `M3System` and call the token from a plain EOA, with no script or console. AC-18: How to Run §7's `cast send` demo uses the real address pattern from `deployments/31337.json` and the real decoded error.
**Action Needed:** 🐞 Debugger reviews T6.1a. ⌨️ Coder builds T6.3. 🧭 Researcher verifies T6.1a and T4.4 after the review.
**Unblocks:** T6.3

---

### 2026-10-28 16:05 PKT · ⌨️ Coder → 🐞 Debugger, 🧭 Researcher · HANDOFF (ruling asks + T6.3)
**Context:** Researcher 15:50 ruling: ask 3, ask 9, and the T6.3 scope.
**On Disk Now:** `scripts/onboard/onboard.test.mjs` → `test_RunExitsNonZeroOnScriptRevert` (renamed from `test_ScriptRevertExitsFour`; asserts exit 4) and `test_NoKeyMaterialCommitted` · `contracts/test/registry/BypassTest.t.sol` (8 tests) · How to Run §8 · `forge test` → `229 tests passed, 0 failed` · `pnpm test:onboard` → `pass 12, fail 0`.
**Message:**
1. Ask 9: the literal AC-T5-4 grep now flags `contracts/script/input/custodian.json:3 "custodianKeyHash": "0xd14f…ee13"`. That value is a hash of the public key, not a key. `test_NoKeyMaterialCommitted` runs the same check over git-tracked files under `contracts/script`, allows only that `custodianKeyHash` field, and asserts nothing under `contracts/.onboard/` is tracked. The AC-T5-4 wording may want the same exception.
2. T6.3 is built on `M3System` with plain EOAs calling the token: `test_DirectTransferToUnverifiedReverts` and `test_DirectMintToUnverifiedReverts` → `ReceiverNotVerified(wallet)`; `test_DirectMintWhenAssetNotLiveReverts` → `TransferNotCompliant(address(0), alice, 1e18)` for both PENDING and FROZEN; `test_DirectTransferWhenAssetFrozenSucceeds`; `test_DirectMintWhenReserveStaleReverts`; `test_DirectMintBeyondReserveReverts`. There are two extras: `test_DirectMintByNonAgentReverts` → `NotAuthorisedAgent`, and `test_DirectComplianceHookCallReverts` → `NotBoundToken`.
3. AC-18 was checked on a fresh anvil after an AC-24 run. `cast send $TOKEN transfer($UNVERIFIED, 1)` from the provider gave `custom error 0x69d5fea9 … ReceiverNotVerified(0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc)`. How to Run §8 shows that exact output and where `$TOKEN` comes from. (Onboarding is now §7, so the bypass demo is §8.)
**Action Needed:** 🐞 Debugger reviews T6.3 and the two new node tests. 🧭 Researcher verifies T6.3 / AC-17 and AC-18.
**Unblocks:** T6.1b

---

### 2026-10-28 15:25 PKT · 🐞 Debugger → ⌨️ Coder, 🧭 Researcher · REPORT
**Context:** T6.1a (`ed89bbe`) and T6.3 (`7e9f0e6`) review. Independent run on a fresh anvil.
**On Disk Now:** `forge test` → `Ran 13 test suites: 229 tests passed, 0 failed` · `pnpm test:onboard` → `# pass 12 · # fail 0` · `forge fmt --check` and prettier clean · AC-24 sequence (DeployM3 → VerifyWallet → `m3:fixture-attestation --ts now` → `m3:onboard --broadcast`) → 5 txs (register, setTokenFor, submitAttestation, admit, mint); `cast`: supply `999900000000000000000`, reserve `999900000000000000000`, state `2` (LIVE) · re-run → `ONBOARD_STATUS=ALREADY_LIVE`, exit 0, nothing sent · tampered signature → `BadAttestationSig`, `node scripts/onboard/run.mjs` exit **3** · second lot on the bound token → `TokenBoundToOtherAsset(...)`, "Nothing was sent", exit **4** (forge-exits-0 guard works).
**Message:** **PASS** on behaviour; BypassTest covers AC-17 (as corrected), stale-reserve and beyond-reserve mints, non-agent mint, direct hook call. Two mechanical findings for ⌨️ Coder:
1. **Exit codes lost through pnpm.** The documented command `pnpm m3:onboard …` exits **1** where `node scripts/onboard/run.mjs …` exits 3 (repro: flip one hex digit of `signature` in `gold-lot-002.seq1.att.json`, run both). pnpm 9 collapses a script's non-zero code to 1, so How to Run §7's exit-code table (2/3/4) is false for the command it documents, and T6.1b/T6.2 cannot branch on it. Fix: document and use `node scripts/onboard/run.mjs` wherever the code matters (or rely on the `ONBOARD_STATUS=` line), and add a node test that asserts the code through the real entry point.
2. **Fixture generator dirties a tracked file.** Step 3 of AC-24 overwrites the committed `contracts/script/input/gold-lot-002.seq1.att.json`, so every rehearsal leaves `git status` dirty. Write to `contracts/.onboard/` (git-ignored) or document `git checkout` after the run.
**Action Needed:** ⌨️ Coder fixes 1 and 2. 🧭 Researcher may VERIFY T6.3; T6.1a after the fixes.
**Unblocks:** T6.1b

---

### 2026-10-28 16:20 PKT · ⌨️ Coder → 🐞 Debugger · HANDOFF (review fixes)
**Context:** Debugger review of `7e9f0e6` (entry above): (1) pnpm collapses exit codes, (2) the fixture generator dirties tracked files.
**On Disk Now:** How to Run §7 → steps 3–4 are now `node scripts/onboard/make-fixture-attestation.mjs …` and `node scripts/onboard/run.mjs …`, and the exit-code table says it is for `node scripts/onboard/run.mjs` · `make-fixture-attestation.mjs` writes only under `contracts/.onboard/` (the keypair, `custodian.mldsa65.pub`, `custodian.json`, `<slug>.seq<n>.att.json`) · `lib.mjs` `custodianKeyDir(contractsDir, chainId)` → `.onboard/` on 31337 when present, else `script/input/` · `contracts/script/input/gold-lot-002.seq1.att.json` removed; the example input points at `.onboard/gold-lot-002.seq1.att.json` · `pnpm test:onboard` → `pass 14, fail 0` · fresh anvil AC-24 rerun: `exit 0`, re-run `exit 0`, and `git status` shows no tracked change from the rehearsal.
**Message:**
1. Every exit-code test runs the real entry, `node scripts/onboard/run.mjs` (`RUN` in the test file), which is now the documented command. `pnpm m3:onboard` stays as a convenience, and How to Run says pnpm reports any failure as 1.
2. New tests: `test_FixtureKeyIsDevnetOnly` (off anvil, the `.onboard/` key is ignored and only the committed key counts, so a missing one is `CustodianKeyMissing`, exit 3) and `test_FixtureGeneratorLeavesTrackedFilesAlone`. The custodian key is now loaded only after the chain and asset checks.
**Action Needed:** 🐞 Debugger re-checks.
**Unblocks:** T6.1a VERIFY

---

Up: [[Tasks/T6 - Provider Onboarding Console]]
