# ADR 0026 — Ops Console Frontend Stack: React 18, Vite, Viem

- **Status:** Accepted (2026-10-28, Q21)
- **Date:** 2026-10-27
- **Deciders:** Fahad Naseer
- **Answers:** Q9 / T6.1b. **Depends on:** ADR 0015 (agent powers & key tiers), ADR 0016 (one token per asset), ADR 0025 (immutable deployments)

## Context

Task T6.1b wraps the provider onboarding workflow into a UI console (`apps/ops-console`). Today `apps/ops-console` contains only an empty TypeScript package stub (`src/index.ts`). A frontend stack was required for the operator/provider console that can interact directly with on-chain contracts without adding heavy backend dependencies.

## Decision

1. **Framework:** React 18 with Vite as the build tool for `apps/ops-console`.
2. **Blockchain Client:** `viem` for contract interactions and type-safe ABI encoding/decoding.
3. **Execution Sequencing:** The Foundry onboarding script `contracts/script/OnboardAsset.s.sol` (T6.1a) is developed and verified first as the programmatic baseline; the UI console wraps the verified JSON schema (T6.0) and on-chain interactions.
4. **Target Role:** Internal operator tool for MS1 (Q12 Option a); provider self-service deferred to Phase 2.
