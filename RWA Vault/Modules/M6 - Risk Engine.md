---
tags: [rwa-vault, module, m6]
phase: 3
sprint: 7-8
status: not-started
---
# M6 — Risk Engine ⬜

**Depends on:** [[M5 - Oracle & Proof-of-Reserve]] (price rounds) and [[M4 - Vault Accounting]] (locked share balances)
**Done when:** the p95 risk sweep takes < 500 ms at 10,000 positions, and a stopped engine delays liquidations but never causes an incorrect one.

## Tasks
- [ ] `CollateralManager.getCollateralValue()` and `calculateHF()`: a pure function of (q, p, λ, D)
- [ ] TypeScript workers on Redis Streams consumer groups that recompute HF on every accepted price tick, with at-least-once delivery
- [ ] Notifications (borrower alert at HF < 1.15) and liquidation proposals. The engine proposes; the chain decides independently.
- [ ] k6 load test: 10,000 open positions, one price tick per second

Prev: [[M9 - Anchoring & Audit]] · Next: [[M7 - Lending & Liquidation]] · Up: [[All Modules]]
