---
tags: [rwa-vault, m3, thread, t6]
task: T6.0
status: in-progress
lead_agent: debugger
updated: 2026-10-27
---
# 💬 Agent Thread — T6.0: Onboarding Schema & Parity

> **Topic:** Declarative onboarding schema (`packages/types/src/onboarding.ts`), Ajv JSON schema parity, and edge-case boundary validation.  
> **Status:** 🐞 Debugger → ⌨️ Coder (Batch 2 rulings delivered; ready for implementation).

---

### 2026-10-27 11:00 · 🧭 Researcher → ⌨️ Coder · PLAN
**Context:** T6.0 Provider onboarding schema specification.
**On Disk Now:** `packages/types/schema/onboarding.json` & `packages/types/src/onboarding.ts`
**Deliverable:** TypeScript validation function `validateOnboardingInput` + JSON schema + golden test vector `GOLD_LOT_001`.
**Spec Reference:** [[Specs/T6 - Provider Onboarding Console]]

---

### 2026-10-27 15:30 · ⌨️ Coder → 🐞 Debugger · HANDOFF
**Context:** Initial schema implementation and tests.
**On Disk Now:** `packages/types/src/__tests__/onboarding.test.ts`
**Status:** 13/13 unit tests green. Handing over for adversarial edge-case analysis.

---

### 2026-10-27 17:45 · 🐞 Debugger → 🧭 Researcher · ASK (Round 2 Questions)
**Context:** Boundary probe found 7 edge cases where specification was ambiguous:
1. **B13 (`valuationTs`):** Year 2100 accepted. How far into the future is permitted? Clock skew $\delta$?
2. **B10 (`uint256` bounds):** How should JSON schema enforce $2^{256}-1$ without a giant unmaintainable regex?
3. **B16 (`treasuryWallet == token`):** Reject or warn? (Validator has no warning channel).
4. **B4 (`assetId` pattern):** Are trailing hyphens (`gold-`) and double hyphens (`go--ld`) legal?
5. **B14 (`currency`):** Format-only regex or ISO 4217 currency allow-list?
6. **Zero-width characters:** Invisible descriptions passing `trim()`.
7. **Ajv Dependency:** May we commit Ajv as a `devDependency` to guarantee independent parity checking?

---

### 2026-10-27 20:15 · 🧭 Researcher → 🐞 Debugger & ⌨️ Coder · RULING (Round 2)
**Context:** Official design rulings on all 7 questions:
1. **Q1 (B13 `valuationTs`):** Reject `valuationTs > now`. No warning channel; hard reject matching T0.6 `ValuationInFuture`.
2. **Q2 (B10 `uint256`):** Schema uses `maxLength: 78`. TypeScript enforces exact `BigInt(v) <= UINT256_MAX`.
3. **Q3 (B16 Treasury):** Pre-flight validation reject. Treasury wallet cannot equal token address.
4. **Q4 (B4 `assetId`):** Tighten regex to `^[a-z0-9]+(-[a-z0-9]+)*$` (no trailing or adjacent hyphens).
5. **Q5 (B14 Currency):** Keep format-only `^[A-Z]{3}$` for MS1.
6. **Q6 (Zero-width):** Require at least one printable non-whitespace ASCII character.
7. **Ajv devDependency:** **APPROVED by Fahad.** "Dependency-free" governs production runtime packages, not test harnesses.

---

### 2026-10-27 22:00 · 🐞 Debugger · REPORT
**Context:** Batch 2 status and failing regression tests.
**On Disk Now:** 4 intentional failing tests committed in `onboarding.test.ts` (B10, B13, B15, C4).
**Next Action:** ⌨️ Coder to apply the 7 Batch 2 rulings in `packages/types/src/onboarding.ts` to turn suite 100% green.

---

Up: [[Tasks/T6 - Provider Onboarding Console]] · Reference: [[Specs/T6 - Provider Onboarding Console]]
