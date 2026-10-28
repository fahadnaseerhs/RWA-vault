---
tags: [rwa-vault, module, m7]
phase: 3
sprint: 8-10
status: not-started
---
# M7 — Lending & Liquidation ⬜

**Depends on:** [[M6 - Risk Engine]], [[M5 - Oracle & Proof-of-Reserve]], [[M4 - Vault Accounting]]
**Done when:** a 10,000-path Monte Carlo at 3σ produces zero bad debt, and the buffer reduces liquidations from transient shocks without masking sustained under-collateralisation (Experiment B).

## Tasks
- [ ] `LendingPool.sol`: global borrow index (Model 4) with O(1) rate change and O(1) per-user debt; two-slope rate curve with the kink at U* = 80%
- [ ] `CollateralManager.sol`: BorrowCapacity and HF (Model 3); post-borrow HF ≥ 1.15 as a hard invariant
- [ ] `ReserveBuffer.sol` (Model 5): claims in the 0.95 ≤ HF < 1.00 band, per-epoch cap κ = 0.40 × B, non-destructive release, falls back cleanly to normal liquidation
- [ ] `Liquidator.sol` (Model 6): close factor φ = 0.50; bonus decays β_max → β_min over 20 blocks; uses only the last committed oracle price
- [ ] Per-asset parameter table (θ, λ, β_max, heartbeat): gold is mandatory; T-bill, Sukuk and REIT are stretch goals
- [ ] Echidna + Foundry invariants: post-state HF never < 1.15, locked shares ≤ held shares, every liquidation strictly raises HF, at most one buffer claim per position

## MS3 demo (week 19)
Lock → borrow → price drop → buffer band → buffer absorbs, or a decaying-bonus liquidation runs → HF goes up with zero bad debt. At least one liquidation that the control build performs is prevented.

Prev: [[M6 - Risk Engine]] · Next: [[M10 - Clients]] · Up: [[All Modules]]
