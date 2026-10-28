---
tags: [rwa-vault, module, m11]
phase: 4
sprint: 11-13
status: not-started
---
# M11 — Evaluation Harness ⬜

**Depends on:** M0–M10 feature-complete
**Done when:** every research-question table in §VII of the proposal is filled from measured runs, not projected arithmetic.

## Tasks
- [ ] ECDSA-only control build behind the `AUTH_MODE` compile flag, differing from the PQ build in exactly one dimension
- [ ] Foundry gas snapshots for all 11 contracts in both builds; anchoring amortisation curve from n = 1 to 4,096; measured break-even n* vs `ecrecover` (predicted ≈ 14)
- [ ] RQ2 latency: k6 on testnet, p50/p95 per flow step at 1, 10 and 100 users
- [ ] RQ4 buffer study: replays of the 2020 and 2024 gold drawdowns plus 10,000 GBM paths at 1σ/2σ/3σ, comparing the control build to Model 5
- [ ] RQ3 oracle-attack suite: 1/2/3 malicious sources, stale source, large deviation, correlated majority
- [ ] Verify the non-functional targets in Table 8 of the proposal
- [ ] Reproduction scripts, dataset package, ADR log and thesis assembly

Prev: [[M10 - Clients]] · Up: [[All Modules]]
