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
updated: 2026-10-27
---
# 📋 Task Group T6 — Provider Onboarding Console

> **Decisions Applied:** Q9=B (UI in `apps/ops-console`, Foundry script first, ADR 0026), Q12=a (Internal operator console for MS1).  
> Status lives in frontmatter. T6.0 is built and green on disk and awaits Researcher VERIFY; T6.1a, T6.1b and T6.3 are blocked behind T1–T5.

## Blockers (as of 2026-10-27)
| Blocker | Kind | Owner | Clears when |
|---|---|---|---|
| T6.0 not yet verified (code is green: `@rwa-vault/types` 32/32, 2026-10-27) | task | 🧭 Researcher | `VERIFY ✅` in the T6.0 thread |
| No `AssetRegistry`, `Token`, registries, compliance or deploy script exist (T1–T5) | task | ⌨️ Coder | T5.1 green |
| How many signers and clauses the attestation has | decision | 👤 Fahad | [[Questions/Q17 - Does the insurer co-sign at MS1, or after it\|Q17]] decided |
| Where the ML-DSA-65 signature is checked (no on-chain verifier exists) | decision | 👤 Fahad | [[Questions/Q18 - Where is the ML-DSA-65 signature checked for MS1\|Q18]] decided |
| Task 6 sequencing | decision | 👤 Fahad | [[Questions/Q19 - What does the Coder do while T6 waits for T1-T5\|Q19]] decided |
| The T6.0 code is local only, not on GitHub | decision | 👤 Fahad | [[Questions/Q20 - Push the local-only work to GitHub\|Q20]] decided |
| No named non-author tester for T6.2 | decision | 👤 Fahad | [[Questions/Q22 - Who runs the T6.2 unaided onboarding rehearsal\|Q22]] decided |
| Real envelope path needs M2 codec/verifier (skeleton today) | external | M2 | M2 T3/T4 — until then the fixture envelope + banner (ADR 0017) |
| `apps/ops-console` has no UI stack (ADR 0026 Proposed only) | task | ⌨️ Coder | scaffold after T6.1a |

### Subtasks Checklist
- [ ] **T6.0** 🧭 **In review** — Shared onboarding schema (`packages/types/src/onboarding.ts`, `schema/onboarding-input.schema.json`) and Ajv parity harness. Batch 2 applied; 32/32 green. Awaiting Researcher `VERIFY ✅` (see [[Threads/Thread - T6.0 Onboarding Schema & Parity]]).
- [ ] **T6.1a** Foundry onboarding script `contracts/script/OnboardAsset.s.sol` (declarative JSON input, idempotent, named error translations). *(Queued after T5.1)*.
- [ ] **T6.1b** UI page in `apps/ops-console` (React 18 + Vite + Viem per ADR 0026).
- [ ] **T6.2** Unaided onboarding rehearsal (tester: [[Questions/Q22 - Who runs the T6.2 unaided onboarding rehearsal|Q22]]); protocol can be written now, run after T6.1a; documented in `docs/reports/M3-onboarding-rehearsal.md`.
- [ ] **T6.3** Acceptance bypass test `contracts/test/registry/BypassTest.t.sol` (direct-contract bypass attempts rejected on-chain).

Up: [[M3 Task Board and Todo]] · Thread: [[Threads/Thread - T6.0 Onboarding Schema & Parity]]
