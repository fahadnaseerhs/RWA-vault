---
tags: [rwa-vault, m3, task]
type: task
id: M3-T0
status: in-progress
agent: researcher
progress: 7/8
thread: "[[Threads/Thread - T0.6 AssetRegistry Interface]]"
updated: 2026-10-27
---
# 📋 Task Group T0 — Interface PR & Behavioural Guarantees

> **Ownership:** Researcher (scaffolding & criteria) · Status: Scaffold largely complete (Commit `0b2dd0e`).

### Subtasks Checklist
- [x] **T0.1** ERC-3643 token interface `contracts/src/tokens/interfaces/IERC3643.sol`
- [x] **T0.2** Identity registry suite (`IIdentityRegistry.sol`, `IIdentityRegistryStorage.sol`, `IClaimTopicsRegistry.sol`, `ITrustedIssuersRegistry.sol`)
- [x] **T0.3** ONCHAINID interfaces (`IIdentity.sol`, `IClaimIssuer.sol`, `IERC734.sol`, `IERC735.sol`)
- [x] **T0.4** Modular compliance interfaces (`IModularCompliance.sol`, `IModule.sol`)
- [x] **T0.5** `abstract` acceptance spec `contracts/test/registry/ERC3643Acceptance.t.sol` (6 core guarantees)
- [x] **T0.6** ✅ **VERIFIED & CHECKMARKED by Researcher** — `IAssetRegistry.sol` + `AssetRegistryMock` in `AssetRegistryInterface.t.sol`. 12 views, 3 agent, 7 owner, 11 events, 21 errors, 22 selectors. 6/6 tests passing. (ADR 0019).
- [ ] **T0.7** `IReserveAttestationSource.sol` research note: full spec for the seam M5 later satisfies (Q5=A, ADR 0017).
- [ ] **T0.8** Consumer sign-off (M4, M5, M9 owners) on interface signatures.

Up: [[M3 Task Board and Todo]] · Thread: [[Threads/Thread - T0.6 AssetRegistry Interface]]
