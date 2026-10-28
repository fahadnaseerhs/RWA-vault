---
type: decision
id: M3-Q19
module: M3
status: decided
raised_by: researcher
raised_on: 2026-10-27
blocks: [T6.1a, T6.1b, T6.3]
recommendation: "A — verify T6.0, write the T6.2 protocol, then move the Coder to T1.1 and T4.1; T6.1a starts when T5.1 is green"
decision: "A — verify T6.0, write the T6.2 protocol, Coder builds T1.1 → T4.1 → T2 → T3 → T5.1; T6.1a → T6.3 → T6.1b after T5.1"
decided_by: Fahad Naseer
decided_on: 2026-10-28
adr: "none (sequencing)"
tags: [rwa-vault, decision, m3, task6]
updated: 2026-10-27
---
# Q19 — What order does Task 6 run in, given T1–T5 are not built?

**Why it matters (plain words):** T6.1a (onboarding script), T6.3 (bypass test) and T6.1b (UI) all call contracts that do
not exist yet — no `AssetRegistry`, `Token`, registries or deploy script. Code written against nothing cannot be
verified, which breaks the Done rule.

**Blocks:** T6.1a, T6.1b, T6.3 · **Does not block:** T6.0 verification, T6.2 protocol document

## Options
- **Option A — Close what T6 can close, then build the stack.** (1) Researcher `VERIFY` of T6.0 (32/32 green on disk);
  (2) write the T6.2 rehearsal protocol; (3) Coder moves to T1.1 → T4.1 → T2 → T3 → T5.1; (4) T6.1a → T6.3 → T6.1b
  once T5.1 is green. *Risk:* T6 sits idle for a sprint.
- **Option B — Build T6.1a now against mocks** (`AssetRegistryMock` and a mock token). *Cost:* rework when the real
  contracts land. *Risk:* tests prove the mock, not the system.
- **Option C — Scaffold `apps/ops-console` (ADR 0026) now** in parallel, UI only. *Risk:* UI before the script inverts
  Q9's "script first" decision.

## Recommendation
**Option A.** It follows the research's own split (T6 spec §2) and the Done rule; nothing written in the wait is thrown away.

## Decision
**Option A.** (1) Researcher `VERIFY` of T6.0; (2) T6.2 rehearsal protocol written; (3) Coder builds T1.1 → T4.1 → T2 → T3 → T5.1; (4) T6.1a → T6.3 → T6.1b once T5.1 is green. _(Fahad Naseer, 2026-10-28)_

Up: [[Open Questions for Fahad]] · Related: [[Tasks/T6 - Provider Onboarding Console|T6]], [[Specs/T6 - Provider Onboarding Console|T6 spec §2]]
