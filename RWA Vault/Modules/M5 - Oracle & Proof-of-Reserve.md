---
tags: [rwa-vault, module, m5]
phase: 2
sprint: 4-5
status: not-started
---
# M5 — Oracle & Proof-of-Reserve ⬜

**Depends on:** [[Module 2 - PQ-PKI & Envelope]] (signed envelopes) and [[M3 - Registry & Compliance]] (the registry reads committed rounds)
**Done when:** an injected malicious source is flagged and the committed median doesn't move, and each of Experiment C's 4 named checks rejects at the correct clause.

## Tasks
- [ ] Node workers polling 5 independent price sources in parallel, with a 3 s timeout
- [ ] Aggregation in strict order: drop invalid/stale → quorum ≥ 3 → median → deviation check vs the 30-min TWAP (δ = 10%) → monotonic roundId/timestamp
- [ ] ML-DSA-44 signing of each accepted round; `PriceOracle.sol` re-verifies the signer role and monotonicity
- [ ] Explicit-refusal failure mode: no round is committed if any check fails, and prices are never extrapolated
- [ ] Heartbeat freshness gate per asset class (60 s for gold). A stale price freezes new borrows/locks but never blocks repay or withdraw.
- [ ] Custodian re-attestation flow that reuses the M3 predicate

Prev: [[M4 - Vault Accounting]] · Next: [[M8 - Settlement Rail]] · Up: [[All Modules]]
