---
tags: [rwa-vault, module, m0]
phase: 1
sprint: 1
status: mostly-done
---
# M0 — Foundation & Devnet 🟡

**Depends on:** nothing (entry point)
**Done when:** a one-command devnet boots on a clean clone and CI is green.

## Tasks
- [x] pnpm workspace monorepo (`apps/`, `packages/`, `services/`, `contracts/`)
- [x] Foundry project (Solidity 0.8.26, OpenZeppelin 5.x) in `contracts/`
- [x] Docker Compose: Anvil, PostgreSQL 16, Redis 7 (`infra/docker-compose.yml`)
- [ ] Documented self-hosted equivalent for every free-tier service. *Not checked yet.*
- [x] GitHub Actions CI: forge build/test/fmt, invariants job, `pnpm -r build/test`, pq-native, pq-wasm
- [ ] **Deployment scripts targeting Arbitrum Sepolia.** `contracts/script/` is empty.
- [ ] Branch protection: trunk-based, feature flags, two required approvals. *This is a GitHub setting, so check it in the repo settings.*

Next: [[Module 1 - PQ Core]] · Up: [[All Modules]]
