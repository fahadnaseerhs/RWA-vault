---
tags: [rwa-vault, m3, task]
type: task
id: M3-T2
status: ready
agent: coder
progress: 0/4
unblocked_by: ["Q04=A", "Q06=A"]
updated: 2026-10-27
---
# 📋 Task Group T2 — Modular Compliance

> **Decisions Applied:** Q4=A (`AssetLiveModule` vetoes transfers unless asset is LIVE, ADR 0014), Q6=A (AssetLiveModule only for MS1).  
> **Status:** Unblocked and ready for Coder implementation (can build directly against `AssetRegistryMock`).

### Subtasks Checklist
- [ ] **T2.1** `ModularCompliance` base: bind token, add/remove modules, `canTransfer` fan-out.
- [ ] **T2.2** `AssetLiveModule` (`IModule`): returns `false` (never reverts) if asset is not LIVE. Reads `IAssetRegistry.assetOfToken(msg.sender)`.
- [ ] **T2.3** Evaluate official `SupplyLimitModule` for `attestedSupply <= reserveAmount` ceiling enforcement.
- [ ] **T2.4** Unit tests for module bind/unbind and multi-module veto fan-out.

Up: [[M3 Task Board and Todo]]
