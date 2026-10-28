---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q09
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q9 — What is the "minimal provider console" — real UI, or script/CLI?
**Why it matters:** the done-criterion is "a provider onboards a gold lot unaided." That needs *some* interface for metadata + valuation basis + custodian + trigger attestation.
- **Option A — A Foundry/TS script (`contracts/script/` or a small CLI).** Fastest path to "unaided onboarding"; demo-able; no frontend time.
- **Option B — A minimal page in `apps/ops-console`.** More convincing for the demo/thesis, more time.
- **Recommendation:** **Option A** for MS1; upgrade to B if the schedule allows, reusing the same on-chain calls.
- **Blocks:** who owns this (frontend vs contracts), the demo script.
- `Decision:` **Option B** — a page in `apps/ops-console`. Build the onboarding **script first** (the deploy/smoke path needs it anyway), then wrap it in the UI; the script is the fallback if the UI slips, so the MS1 gate is never at risk. Scope decision, no ADR. _(Fahad Naseer, 2026-10-27)_