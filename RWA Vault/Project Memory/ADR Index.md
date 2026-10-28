---
tags: [rwa-vault, adr, index]
updated: 2026-10-27
---
# 🏛️ Architecture Decision Records (ADR Index)

> **Source of Truth:** `docs/adr/`. ADRs are immutable once accepted.  
> **Claim-By-File Rule:** Numbers are reserved only by committing `docs/adr/00XX-<slug>.md`. The next available number is **0028**.

| # | Title | Status | Module | Answers / Scope |
|---|---|---|---|---|
| `0001` | Architecture decision record format | Accepted | M0 | Meta |
| `0002` | The PQ primitive inventory is six, and M1 owns all six | Accepted | M1 | Crypto Inventory |
| `0003` | PQ implementation sources: vendored PQClean C + pure Rust | Accepted | M1 | Implementation Sources |
| `0004` | Browser WASM target: `wasm32-unknown-unknown` with C shim | Accepted | M1 | Client Signing |
| `0005` | Native Node bridge: N-API addon via napi-rs + CLI | Accepted | M1 | Server Runtime |
| `0006` | The M1 byte encoding contract | Accepted | M1 | Wire Protocol |
| `0007` | Random source: OS CSPRNG natively, Web Crypto in WASM | Accepted | M1 | Entropy |
| `0008` | Supported platforms and M1 CI matrix | Accepted | M1 | Target CI |
| `0009` | Test-vector inventory and what "conformance" means | Accepted | M1 | ACVP / KAT |
| `0010` | Benchmark reference environments and measurement protocol | Accepted | M1 | Benchmarks |
| `0011` | ETHFALCON: pin the commit, and use NIST-compliant verifier | Accepted | M1 | On-chain Falcon |
| `0012` | Hybrid ERC-3643: vendor `onchain-id`, build registries & compliance | Accepted | M3 | Q1 |
| `0013` | Investor claims stay ECDSA; PQ guards the reserve attestation | Accepted | M3 | Q3 |
| `0014` | Asset liveness is a compliance module, not a token check | Accepted | M3 | Q4 |
| `0015` | Agent powers governed; roles mapped to PQ key tiers | Accepted | M3 | Q7, Q10 |
| `0016` | One ERC-3643 token per asset, with shared identity storage | Accepted | M3 | Q8 |
| `0017` | Reserve data reaches M3 through a stubbed interface seam | Accepted | M3 | Q5 |
| `0018` | Valuation freshness window: 24 hours for gold, set not compiled | Accepted | M3 | Q13 |
| `0019` | Asset admission and freeze semantics in the AssetRegistry | Accepted | M3 | Q14, Q16 |
| `0020` | One token is one fine gram of gold ($10^{18}$ base units) | Accepted | All | C5 |
| `0021` | A stale reserve attestation freezes minting only | Accepted | M3/M5 | C9 |
| `0022` | Platform holds no money: fiat rail is an on-ramp seam | Accepted | M8 | C7 |
| `0023` | Redemption is cash-settled; physical delivery specified, not built | Accepted | M3/M8 | C6 |
| `0024` | A token is fractional title to an identified lot | Accepted | All | C8 |
| `0025` | M3 contracts are immutable: plain deploys, no proxies | Accepted | M3 | Q15 |
| `0026` | Ops Console Frontend Stack: React 18, Vite, Viem | Accepted | M3 | Q9, T6.1b |
| `0027` | Clause 1 verified off-chain for MS1; envelope hash anchored (wording note 2026-10-28: `pqctl` is SLH-DSA-only, so the M1 ML-DSA-65 verify is reached through `@rwa-vault/pq-core`; see [[Specs/T6.1a - Onboarding Script Spec]] §8) | Accepted | M3 | Q18 |

Up: [[Project Memory]] · Related: [[Module 1 - PQ Core]], [[Module 3 - Registry & Compliance]]
