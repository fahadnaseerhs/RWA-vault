---
tags: [rwa-vault, m3, task]
type: task
id: M3-T3
status: in-progress
agent: coder
progress: 4/6
unblocked_by: ["Q08=A", "Q10=implement", "Q16=A"]
spec: "[[Specs/T3 - ERC-3643 Token Build Spec]]"
updated: 2026-10-28
---
# 📋 Task Group T3 — ERC-3643 Permissioned Token

> **Decisions Applied:** Q8=A (One token per asset, shared identity storage, ADR 0016), Q10=implement (`forcedTransfer` behind 2-of-3 multisig + timelock, ADR 0015), Q16=A (Frozen asset blocks minting only; holder transfers allowed, ADR 0019).  
> **Status:** Unblocked and ready for Coder implementation.

### Subtasks Checklist
- [x] **T3.1** ✅ `Token.sol` implementing `IERC3643`: `mint` and `transfer` calling `isVerified` and `canTransfer`.
- [x] **T3.2** ✅ Wallet freeze (full + partial) and token pause mechanics.
- [ ] **T3.3** _(one fix owed: recovery to a wallet of another identity, see the T3 thread 15:20)_ Implement `forcedTransfer`, `burn`, and `recoveryAddress` with multisig governance.
- [x] **T3.4** ✅ Batch transfer and mint operations.
- [ ] **T3.5** ~~`TokenFactory`~~ — Deferred until second asset enters demo (Q8=A).
- [x] **T3.6** ✅ Concrete implementation of `contracts/test/registry/ERC3643Acceptance.t.sol` passing all 6 guarantees.

Up: [[M3 Task Board and Todo]] · Thread: [[Threads/Thread - T3 ERC-3643 Token]]
