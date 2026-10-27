---
tags: [rwa-vault, module, m10]
phase: 3
sprint: 7-10
status: not-started
---
# M10 — Clients ⬜

**Depends on:** the [[M3 - Registry & Compliance]], [[M4 - Vault Accounting]] and [[M7 - Lending & Liquidation]] interfaces being frozen
**Done when:** a non-technical tester completes the full investor journey, from deposit to liquidation visibility, without help.

## Tasks
- [ ] Investor client: React 18 PWA with TypeScript, viem and TanStack Query (the `apps/client` shell exists)
- [ ] WASM Falcon signer wired into the deposit, borrow and repay flows, with the key kept in IndexedDB and never transmitted
- [ ] Provider console (onboarding, attestation) and operations console (risk and liquidation monitoring; the `apps/ops-console` shell exists)
- [ ] ABI-typed contract bindings, so a contract change becomes a compile error

Prev: [[M7 - Lending & Liquidation]] · Next: [[M11 - Evaluation Harness]] · Up: [[All Modules]]
