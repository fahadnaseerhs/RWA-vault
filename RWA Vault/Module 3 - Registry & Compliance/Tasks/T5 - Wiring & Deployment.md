---
tags: [rwa-vault, m3, task]
type: task
id: M3-T5
status: ready
agent: coder
progress: 0/3
unblocked_by: ["Q07=A", "Q15=A"]
spec: "[[Specs/T5.1 - Deploy Script Spec]]"
updated: 2026-10-28
---
# 📋 Task Group T5 — Wiring & Deployment

> **Decisions Applied:** Q7=A (Owner = 2-of-3 multisig, Agent = Tier 1 service key, ADR 0015), Q15=A (Immutable deploys, ADR 0025).  
> **Status:** Queued after contracts pass unit testing.

### Subtasks Checklist
- [ ] **T5.1** Deploy script in `contracts/script/DeployM3.s.sol` wiring Token ↔ Registries ↔ Storage ↔ Topics ↔ Compliance ↔ AssetLiveModule.
- [ ] **T5.2** Role assignment per ADR 0015 (`owner` = 2-of-3 multisig, `agent` = Tier 1 service key; setters behind multisig).
- [ ] **T5.3** Devnet deployment and smoke script onboarding one gold lot.

Up: [[M3 Task Board and Todo]]
