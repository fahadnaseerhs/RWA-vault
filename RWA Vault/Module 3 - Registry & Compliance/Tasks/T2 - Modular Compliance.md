---
tags: [rwa-vault, m3, task]
type: task
id: M3-T2
status: ready
agent: coder
progress: 1/4
unblocked_by: ["Q04=A", "Q06=A"]
spec: "[[Threads/Rounds/T2 - Researcher Rulings (round 1)]]"
updated: 2026-10-28
---
# 📋 Task Group T2 — Modular Compliance

> **Decisions Applied:** Q4=A (`AssetLiveModule` in ModularCompliance, ADR 0014), Q16=A (it vetoes **mints only** when the asset is not LIVE — transfers continue, ADR 0019 §6), Q6=A (AssetLiveModule only for MS1).  
> **Status:** Unblocked and ready for Coder implementation (can build directly against `AssetRegistryMock`).

### Subtasks Checklist
- [ ] **T2.1** `ModularCompliance` base: bind token, add/remove modules, `canTransfer` fan-out.
- [ ] **T2.2** `AssetLiveModule` (`IModule`): returns `false` (never reverts) for a **mint** (`from == address(0)`) when the asset is not LIVE; always `true` for transfers (ADR 0019 §6). Reads `IAssetRegistry.assetOfToken(msg.sender)`.
- [x] **T2.3** ✅ Evaluated and rejected: the cap lives in `AssetLiveModule`, read live from `reserveOf` (see [[Threads/Rounds/T2 - Researcher Rulings (round 1)]]).
- [ ] **T2.4** Unit tests for module bind/unbind and multi-module veto fan-out.

Up: [[M3 Task Board and Todo]]
