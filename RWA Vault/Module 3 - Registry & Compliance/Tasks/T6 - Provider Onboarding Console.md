---
tags: [rwa-vault, m3, task]
type: task
id: M3-T6
status: in-progress
agent: debugger
progress: 1/5
unblocked_by: ["Q09=B", "Q12=a"]
thread: "[[Threads/Thread - T6.0 Onboarding Schema & Parity]]"
spec: "[[Specs/T6 - Provider Onboarding Console]]"
updated: 2026-10-27
---
# 📋 Task Group T6 — Provider Onboarding Console

> **Decisions Applied:** Q9=B (UI in `apps/ops-console`, Foundry script first, ADR 0026), Q12=a (Internal operator console for MS1).  
> **Status:** Active in agent loop. T6.0 schema in progress; T6.1a/b queued behind T5.1 deployment wiring.

### Subtasks Checklist
- [ ] **T6.0** 🐞 **In Progress** — Shared onboarding schema (`packages/types/src/onboarding.ts`) and Ajv parity test harness. Batch 2 rulings ready for Coder. (See [[Threads/Thread - T6.0 Onboarding Schema & Parity]]).
- [ ] **T6.1a** Foundry onboarding script `contracts/script/OnboardAsset.s.sol` (declarative JSON input, idempotent, named error translations). *(Queued after T5.1)*.
- [ ] **T6.1b** UI page in `apps/ops-console` (React 18 + Vite + Viem per ADR 0026).
- [ ] **T6.2** Unaided onboarding rehearsal documented in `docs/reports/M3-onboarding-rehearsal.md`.
- [ ] **T6.3** Acceptance bypass test `contracts/test/registry/BypassTest.t.sol` (direct-contract bypass attempts rejected on-chain).

Up: [[M3 Task Board and Todo]] · Thread: [[Threads/Thread - T6.0 Onboarding Schema & Parity]]
