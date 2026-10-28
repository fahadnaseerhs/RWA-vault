---
tags: [rwa-vault, m3, task]
type: task
id: M3-T6
status: blocked
agent: researcher
progress: 1/5
unblocked_by: ["Q09=B", "Q12=a"]
thread: "[[Threads/Thread - T6.0 Onboarding Schema & Parity]]"
spec: "[[Specs/T6 - Provider Onboarding Console]]"
updated: 2026-10-28
---
# 📋 Task Group T6 — Provider Onboarding Console

> **Decisions Applied:** Q9=B (UI in `apps/ops-console`, Foundry script first, ADR 0026), Q12=a (Internal operator console for MS1).  
> Status lives in frontmatter. T6.0 is verified; T6.1a, T6.1b and T6.3 are blocked behind T1–T5.

## Run order (Q19 = A, 2026-10-28)
1. 🧭 Researcher `VERIFY` of T6.0 → 2. 🧭 write the T6.2 rehearsal protocol → 3. ⌨️ T1.1 → T4.1 → T2 → T3 → T5.1 → 4. ⌨️ T6.1a → T6.3 → T6.1b.

## Blockers (as of 2026-10-28)
| Blocker | Kind | Owner | Clears when |
|---|---|---|---|
| Real envelope path needs M2 codec/verifier (skeleton today) | external | M2 | M2 T3/T4 — until then the fixture envelope + banner (ADR 0017) |
| `apps/ops-console` has no UI stack (ADR 0026 accepted, not scaffolded) | task | ⌨️ Coder | scaffold after T6.1a |

### Subtasks Checklist
- [x] **T6.0** ✅ Shared onboarding schema (`packages/types/src/onboarding.ts`, `schema/onboarding-input.schema.json`) and Ajv parity harness. Verified by the Researcher 2026-10-28 (see [[Threads/Thread - T6.0 Onboarding Schema & Parity]]).
- [ ] **T6.1a** Onboarding command (`pnpm m3:onboard`: off-chain clause-1 verify + `contracts/script/OnboardAsset.s.sol`) and `VerifyWallet.s.sol`. Spec: [[Specs/T6.1a - Onboarding Script Spec]]. *(Ready: T5.1 verified 2026-10-28)*.
- [ ] **T6.1b** UI page in `apps/ops-console` (React 18 + Vite + Viem per ADR 0026).
- [ ] **T6.2** Unaided onboarding rehearsal (tester: Hassan or Fawaz, per [[Questions/Q22 - Who runs the T6.2 unaided onboarding rehearsal|Q22]]); protocol written: [[Specs/T6.2 - Unaided Rehearsal Protocol]]; runs after T6.1a; documented in `docs/reports/M3-onboarding-rehearsal.md`.
- [ ] **T6.3** Acceptance bypass test `contracts/test/registry/BypassTest.t.sol` (direct-contract bypass attempts rejected on-chain).

Up: [[M3 Task Board and Todo]] · Thread: [[Threads/Thread - T6.0 Onboarding Schema & Parity]]
