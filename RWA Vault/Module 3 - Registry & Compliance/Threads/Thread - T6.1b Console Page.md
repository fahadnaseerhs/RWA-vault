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

### 2026-10-28 17:20 PKT · 🐞 Debugger → ⌨️ Coder, 🧭 Researcher · REPORT
**Context:** T6.1b review of `839a3ab` + `a56288e` (rulings 1–3). Independent setup in a clean container: wasm-pack 0.13.1, wasm-bindgen-cli 0.2.127, `wasm-pack build` → `pkg/` (unoptimised).
**On Disk Now:** ops-console `tsc --build`, `eslint src`, `vite build` clean · `vitest run` → `18 passed (18)` (WASM clause-1 test runs) · `forge test` → `230 passed` · `pnpm test:onboard` → `pass 15` · types → `pass 37` · Playwright (Chromium) on a fresh anvil, after DeployM3, VerifyWallet, fixture: anvil dev key → `✅ Provider wallet … is KYC-verified` → `Custodian signature valid for the registered custodian key` (WASM) → register panel shows slug, 8 fields, `metadataHash`, button disabled until confirm → `State: PENDING` + multisig `to / data` → `cast send` as owner → Re-check → clauses 1–4 ✅ → `State: LIVE` → Mint → receipt `Reserve 999.9 g`, `Supply 999.9 g`, `✅ Invariant: supply ≤ reserve`, FIXTURE line; no page or console errors; `cast`: supply = provider balance = `999900000000000000000`, state `2`.
**Message:** **PASS** for T6.1b (AC-9…14 behaviour, rulings 1–3). One CI finding, not a T6.1b blocker:
- `.github/workflows/ci.yml` `node` job still runs `pnpm typecheck` (`:60`) and `pnpm -r --filter '!@rwa-vault/ops-console' run build/test` (`:63-64`). From a clean clone without `pkg/`, `tsc --build --force` fails in **pq-core** and **ops-console** with `src/wasm.ts(77,32): error TS2307: Cannot find module '../pkg/rwa_vault_pq_core.js'`; pq-core `test` also points at a missing file (M1 S3-13); `pnpm format:check` flags 4 files (2 in pq-core). The `node` job therefore cannot go green. Only latent today because CI runs only on PRs into `main`.
- Setup note for How to Run §7b: where GitHub downloads are blocked, `wasm-pack` falls back to `cargo install wasm-bindgen-cli` **with** `pq:wasm`'s `RUSTFLAGS=--error-unresolved-symbols`, which breaks the host build. Fix: `cargo install wasm-bindgen-cli --version 0.2.127 --locked` first, then `wasm-pack build --mode no-install …`.
**Action Needed:** ⌨️ Coder excludes ops-console from the `node` job's typecheck too (and adds the §7b setup note). 🧭 Researcher: route the pq-core typecheck/build/test/format items to M1. 🧭 Researcher may VERIFY T6.1b.
**Unblocks:** T6.2 rehearsal (console path)

---

### 2026-10-28 17:15 PKT · ⌨️ Coder → 🐞 Debugger · HANDOFF (CI typecheck, §7b note)
**Context:** Debugger 5cf944f: (1) the node job's `pnpm typecheck` fails from a clean clone without `pkg/`; (2) §7b needs the offline wasm-bindgen workaround.
**On Disk Now:** `.github/workflows/ci.yml` → node job `pnpm -r --filter '!@rwa-vault/ops-console' run typecheck`; ops-console's typecheck runs inside its `build` (`tsc --build && vite build`) in the pq-wasm job after `pkg/` exists · How to Run §7b → `cargo install wasm-bindgen-cli --version 0.2.127 --locked`, then `wasm-pack build … --mode no-install`.
**Message:** pq-core's own `wasm.ts:77` TS2307 without `pkg/` still fails the node job's typecheck. That is M1's, for the 🧭 Researcher to add to the M1 list.
**Action Needed:** 🐞 Debugger re-checks. 🧭 Researcher verifies T6.1b.
**Unblocks:** T6.1b VERIFY

---

### 2026-10-28 17:50 PKT · 🐞 Debugger → 🧭 Researcher · REPORT
**Context:** Re-check of `c9c8959` (17:20 CI finding and §7b setup note).
**On Disk Now:** `.github/workflows/ci.yml` node job → `pnpm -r --filter '!@rwa-vault/ops-console' run typecheck`; ops-console typecheck now runs in the `pq-wasm` job after `pkg/` is built; YAML parses.
**Message:** **PASS.** The ops-console part of the finding is closed. Still open, owned by M1: pq-core `wasm.ts:77` TS2307 without `pkg/`, pq-core `test` (S3-13), 2 pq-core files failing `format:check`. T6.1b ready for VERIFY.
**Action Needed:** 🧭 Researcher may VERIFY T6.1b.
**Unblocks:** T6.2 rehearsal

---

### 2026-10-28 16:30 PKT (11:30 UTC) · 🐞 Debugger → 👤 Fahad, 🧭 Researcher · REPORT
**Context:** Full recheck requested by Fahad, at PR #5 head `6be977b` (no code change since `c9c8959`), from a cleaned working tree.
**On Disk Now:** `forge build --force` ok · `forge fmt --check` clean · `forge test` → `Ran 13 test suites: 230 tests passed, 0 failed, 0 skipped`; invariants 3 × `runs: 256, calls: 128000` · types `pass 37` · `pnpm test:onboard` `pass 15` · `abis:check` → `ABIs up to date (9 contracts)` · ops-console typecheck, lint, `vite build` clean, vitest `18 passed (18)` · prettier clean on M3 paths · fresh anvil: DeployM3 + `smoke()` → `SMOKE OK … 999900000000000000000`; second fresh anvil: DeployM3 → VerifyWallet → fixture → console (Chromium) clauses 1–4 ✅ → LIVE → receipt `Supply 999.9 g`, `✅ Invariant: supply ≤ reserve`, no page errors → CLI re-run `ONBOARD_STATUS=ALREADY_LIVE` exit 0 → `cast`: supply = reserve = `999900000000000000000`, state `2`.
**Message:** **All green, no new findings.** Note for rehearsals: `smoke()` onboards the FIXTURE lot and binds the deployment's one token to it, so run either `smoke()` or the gold-lot-002 onboarding on a given deployment, not both (one token per asset, ADR 0016).
**Action Needed:** none from 🐞 Debugger. Open items stay with M1 (pq-core typecheck without `pkg/`, `test` script, format).
**Unblocks:** nothing new

---

Up: [[Tasks/T6 - Provider Onboarding Console]]
