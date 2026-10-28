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

Up: [[Tasks/T6 - Provider Onboarding Console]]
