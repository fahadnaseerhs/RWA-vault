---
tags: [rwa-vault, m3, task]
type: task
id: M3-T3
status: ready
agent: coder
progress: 0/6
unblocked_by: ["Q08=A", "Q10=implement", "Q16=A"]
updated: 2026-10-27
---
# 📋 Task Group T3 — ERC-3643 Permissioned Token

> **Decisions Applied:** Q8=A (One token per asset, shared identity storage, ADR 0016), Q10=implement (`forcedTransfer` behind 2-of-3 multisig + timelock, ADR 0015), Q16=A (Frozen asset blocks minting only; holder transfers allowed, ADR 0019).  
> **Status:** Unblocked and ready for Coder implementation.

### Subtasks Checklist
- [ ] **T3.1** `Token.sol` implementing `IERC3643`: `mint` and `transfer` calling `isVerified` and `canTransfer`.
- [ ] **T3.2** Wallet freeze (full + partial) and token pause mechanics.
- [ ] **T3.3** Implement `forcedTransfer`, `burn`, and `recoveryAddress` with multisig governance.
- [ ] **T3.4** Batch transfer and mint operations.
- [ ] **T3.5** ~~`TokenFactory`~~ — Deferred until second asset enters demo (Q8=A).
- [ ] **T3.6** Concrete implementation of `contracts/test/registry/ERC3643Acceptance.t.sol` passing all 6 guarantees.

Up: [[M3 Task Board and Todo]]
