---
tags: [rwa-vault, module, m4]
phase: 1
sprint: 3
status: not-started
---
# M4 — Vault Accounting ⬜

**Depends on:** [[M3 - Registry & Compliance]] (the vault holds ERC-3643 units of a LIVE asset). Can be built in parallel with M3 once M0 and M1 exist.
**Done when:** 10⁶ fuzzed sequences show no inflation and no rounding-direction violation, and the Halmos proof passes.

## Tasks
- [ ] `AssetVault.sol`: an ERC-4626 subclass with `_decimalsOffset() = 6` (virtual offset σ = 10⁶)
- [ ] Explicit rounding on all 4 conversions: floor on deposit/mint quotes, ceiling on withdraw/redeem costs, always in favour of the pool
- [ ] Inflation (donation) attack hardening per Model 1, making the attack cost ~10⁶ × the target deposit
- [ ] Foundry property fuzzing: 10⁶ deposit–donate–deposit–withdraw–redeposit sequences
- [ ] Halmos symbolic proof of the share arithmetic

Prev: [[M3 - Registry & Compliance]] · Next: [[M5 - Oracle & Proof-of-Reserve]] · Up: [[All Modules]]
