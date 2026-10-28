---
tags: [rwa-vault, module, m8]
phase: 2
sprint: 4
status: not-started
---
# M8 — Settlement Rail (mock) ⬜

**Depends on:** [[M4 - Vault Accounting]] (the vault must exist to receive the USDC)
**Done when:** 1,000 randomised orders leave the ledger balanced, even with injected failures.

## Tasks
- [ ] `IFiatRail` interface: the single seam between mock settlement and a future licensed provider
- [ ] NestJS implementation: mock PKR → test-net USDC, with a double-entry ledger in PostgreSQL
- [ ] Deterministic settlement delay plus injectable failure modes (for Experiment D)
- [ ] Reconciliation job, so the ledger is never left half-settled

Prev: [[M5 - Oracle & Proof-of-Reserve]] · Next: [[M9 - Anchoring & Audit]] · Up: [[All Modules]]
