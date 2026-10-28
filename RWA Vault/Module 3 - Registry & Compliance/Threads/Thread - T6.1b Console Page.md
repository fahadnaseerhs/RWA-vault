---
type: thread
task: T6.1b
module: M3
status: active
tags: [rwa-vault, thread, m3, t6]
updated: 2026-10-28
---
# 💬 Thread — T6.1b Console Page

> Append-only. New entries go at the **bottom**, using [[Template - Thread Entry]]. Never edit or delete an earlier entry;
> correct it with a new entry that links to it. Current state = the last entry.

**Task:** [[Tasks/T6 - Provider Onboarding Console]] · **Spec:** [[Specs/T6 - Provider Onboarding Console]] §4 + [[Specs/T6.1b - Console Page Delta]]

---

### 2026-10-28 16:45 PKT · ⌨️ Coder → 🐞 Debugger, 🧭 Researcher · HANDOFF
**Context:** T6.1b built to T6 §4 and the seven delta points. Stack per ADR 0026 (no new ADR).
**On Disk Now:** `apps/ops-console/{index.html,vite.config.ts}` · `src/onboarding/{deployments,custodian,clause1,logic,chain}.ts` · `src/ui/{App,AssetStep,AttestationStep,AdmitStep,MintStep,common}.tsx` · `src/__tests__/{onboarding.test.tsx,surface.test.ts}` · `packages/types/src/{onboarding-messages,onboarding-hash}.ts` + `fixtures/onboarding-sentences.json` (from `e0e081f`) · `packages/types/src/abis/` (from `eb5359e`) · `scripts/onboard/build-wasm.mjs` (`pnpm pq:wasm`) · `vitest run` → `17 passed` · ops-console `tsc --build`, `eslint src` and `vite build` clean · `forge test` → `230 passed` (adds `test_SentenceVectorsMatchShared`) · `pnpm test:onboard` → `pass 15` · types → `pass 37`.
**Message:** End-to-end in Chromium (Playwright) against a fresh anvil after DeployM3, VerifyWallet and the fixture generator: anvil dev key (agent) → step 1 Next enabled once `isVerified` → step 2 clause 1 verified by pq-core **WASM** → step 3 Register, multisig `to / data` shown, executed with `cast send` as owner, Re-check, clauses 1–4 ✅, Submit → `State: LIVE` → step 4 Mint → receipt `Reserve 999.9 g`, `Supply 999.9 g`, `✅ Invariant: supply ≤ reserve`, FIXTURE line. Mapping to the spec:
- AC-9: `dev`/`build`/`typecheck`/`lint`/`test` scripts; `pnpm -r typecheck` and `pnpm -r lint` pass. `pnpm -r test` fails only in `@rwa-vault/pq-core` (`dist/__tests__/contract.test.js` does not exist; that package has no test sources). This is an M1 defect and was there before this change.
- AC-10: ADR 0026 (Researcher ruling, no 0028).
- AC-11: `AC-11: step 1 waits for isVerified` (2 tests). AC-12: the banner `MS1: reserve is asserted by the custodian, not independently verified` has no close control. AC-13: a forced `ReserveTooLow(R, S)` revert renders the §3.4 sentence, and `container.innerHTML` has no `/0x[0-9a-fA-F]/`. Unknown errors never show hex.
- AC-14 + point 7: `surface.test.ts` asserts the only writes are register / submitAttestation / admit / mint, that none of transfer, transferFrom, batchTransfer, forcedTransfer, burn, recoveryAddress, setAddressFrozen, freezePartialTokens, freeze, unfreeze, pause or unpause appears, and that `setTokenFor` is never written.
- Points 1–6: deployments are bundled per chain id by `import.meta.glob`. The validator, `metadataHash` and the envelope recipe come from `@rwa-vault/types` and are shared with `scripts/onboard` (`test_ScriptUsesSharedRecipesAndSentences`); the golden vector is checked in vitest. The custodian key follows `run.mjs`'s rule (`.onboard/` on 31337, else committed; keccak checked). Signer: an injected wallet, or an anvil dev key on 31337 only, and the owner address is refused (`signerProblem`). The same state branch as T6.1a §3 S, re-read from chain every 4–5 s. Sentences come from one module; Solidity is held to it by the shared vectors.
Coder readings: (1) Step 3 also does `register`, because binding needs a registered asset and the four-step layout has no other place for it. (2) The WASM clause-1 test is `describe.skipIf(no pkg)`, because `pkg/` is a gitignored build output that needs wasm-pack and clang. (3) The `wasm-opt` download is blocked here; the unoptimised package works (`pq:wasm` accepts it with a warning).
**Action Needed:** 🐞 Debugger reviews (setup: `pnpm install`, `pnpm pq:wasm`, `pnpm --filter @rwa-vault/pq-core build`, How to Run §7b). 🧭 Researcher rules on readings 1–3 and verifies AC-9…14.
**Unblocks:** T6.2 rehearsal (console path)

---

### 2026-10-28 16:55 PKT · 🧭 Researcher → ⌨️ Coder, 🐞 Debugger · RULING (readings 1–3)
**Context:** Coder handoff 16:45 (`839a3ab`). VERIFY follows the Debugger's review.
**On Disk Now:** `apps/ops-console/src/__tests__` (AC-11…14) · Coder's Chromium run against anvil ended LIVE.
**Message:**
1. **Step 3 also registers: confirmed, with one condition.** `register` is permanent (ADR 0019 §1), so the step must show the slug, the eight hashed fields and the `metadataHash` and need an explicit confirm click before signing. Component test: `test_RegisterNeedsConfirmOfHashedFields`.
2. **WASM clause-1 test skipping when `pkg/` is missing: not accepted as is.** A skipped test that reads as green is the failure the done-rule exists to stop. It must **fail** when `pkg/` is missing and `CI` is set, and it may skip locally only with a printed `SKIPPED: build pq-core wasm first (pnpm pq:wasm)`. The CI job that runs the console tests builds `pkg/` first.
3. **Unoptimised wasm (wasm-opt blocked): accepted for MS1 and devnet.** Record the bundle size in the handoff. M11 owns any performance claim.
**Also logged:** pq-core's `test` script pointing at a missing file is already M1 **S3-13** ("test file pending"), so there is no new item.
**Action Needed:** ⌨️ Coder applies 1 and 2. 🐞 Debugger reviews. 🧭 Researcher verifies.
**Unblocks:** T6.1b VERIFY

---

### 2026-10-28 17:05 PKT · ⌨️ Coder → 🐞 Debugger, 🧭 Researcher · HANDOFF (rulings 1–3)
**Context:** Researcher 16:55 rulings on readings 1–3.
**On Disk Now:** `src/ui/AdmitStep.tsx` → `RegisterPanel`: shows the slug, the eight hashed fields and the `metadataHash`; "Register asset" stays disabled until the confirm box is ticked · `onboarding.test.tsx` → `test_RegisterNeedsConfirmOfHashedFields` (all nine values shown; a click before confirming sends nothing; after confirming, `register(assetIdOf(slug), metadataHash, slug)`) · `.github/workflows/ci.yml` → the `node` job builds and tests everything except ops-console; the `pq-wasm` job, after `wasm-pack build`, builds types, pq-core and ops-console and runs `pnpm --filter @rwa-vault/ops-console test` · `vitest run` → `18 passed`.
**Message:**
1. Ruling 2 was checked three ways: with `pkg/` → `18 passed`; `pkg/` moved away → `17 passed | 1 skipped` plus `SKIPPED: build pq-core wasm first (pnpm pq:wasm)`; `pkg/` away with `CI=true` → the test **fails** with "packages/pq-core/pkg is missing: CI must run `pnpm pq:wasm` before this test".
2. Ruling 3, bundle sizes from `vite build`, with the WASM unoptimised: `rwa_vault_pq_core_bg.wasm` 300.46 kB, `index.js` 422.39 kB (129.84 kB gzip), `wasm.js` loader 3.90 kB. The WASM is loaded only when step 2 checks a signature.
**Action Needed:** 🐞 Debugger reviews. 🧭 Researcher verifies T6.1b.
**Unblocks:** T6.2 (console path)

---

Up: [[Tasks/T6 - Provider Onboarding Console]]
