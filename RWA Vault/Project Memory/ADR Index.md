---
tags: [rwa-vault, adr, index]
updated: 2026-10-27
---
# 🏛️ Architecture Decision Records (ADR Index)

> **Source of Truth:** `docs/adr/`. ADRs are immutable once accepted.  
> **Claim-By-File Rule:** Numbers are reserved only by committing `docs/adr/00XX-<slug>.md`. The next available number is **0027**.

| # | Title | Status | Module | Answers / Scope |
|---|---|---|---|---|
| `0001` | Architecture decision record format | Accepted | M0 | Meta |
| `0002` | The PQ primitive inventory is six, and M1 owns all six | Proposed | M1 | Crypto Inventory |
| `0003` | PQ implementation sources: vendored PQClean C + pure Rust | Proposed | M1 | Implementation Sources |
| `0004` | Browser WASM target: `wasm32-unknown-unknown` with C shim | Proposed | M1 | Client Signing |
| `0005` | Native Node bridge: N-API addon via napi-rs + CLI | Proposed | M1 | Server Runtime |
| `0006` | The M1 byte encoding contract | Proposed | M1 | Wire Protocol |
| `0007` | Random source: OS CSPRNG natively, Web Crypto in WASM | Proposed | M1 | Entropy |
| `0008` | Supported platforms and M1 CI matrix | Proposed | M1 | Target CI |
| `0009` | Test-vector inventory and what "conformance" means | Proposed | M1 | ACVP / KAT |
| `0010` | Benchmark reference environments and measurement protocol | Proposed | M1 | Benchmarks |
| `0011` | ETHFALCON: pin the commit, and use NIST-compliant verifier | Proposed | M1 | On-chain Falcon |
| `0012` | Hybrid ERC-3643: vendor `onchain-id`, build registries & compliance | Proposed | M3 | Q1 |
| `0013` | Investor claims stay ECDSA; PQ guards the reserve attestation | Proposed | M3 | Q3 |
| `0014` | Asset liveness is a compliance module, not a token check | Proposed | M3 | Q4 |
| `0015` | Agent powers governed; roles mapped to PQ key tiers | Proposed | M3 | Q7, Q10 |
| `0016` | One ERC-3643 token per asset, with shared identity storage | Proposed | M3 | Q8 |
| `0017` | Reserve data reaches M3 through a stubbed interface seam | Proposed | M3 | Q5 |
| `0018` | Valuation freshness window: 24 hours for gold, set not compiled | Proposed | M3 | Q13 |
| `0019` | Asset admission and freeze semantics in the AssetRegistry | Proposed | M3 | Q14, Q16 |
| `0020` | One token is one fine gram of gold ($10^{18}$ base units) | Proposed | All | C5 |
| `0021` | A stale reserve attestation freezes minting only | Proposed | M3/M5 | C9 |
| `0022` | Platform holds no money: fiat rail is an on-ramp seam | Proposed | M8 | C7 |
| `0023` | Redemption is cash-settled; physical delivery specified, not built | Proposed | M3/M8 | C6 |
| `0024` | A token is fractional title to an identified lot | Proposed | All | C8 |
| `0025` | M3 contracts are immutable: plain deploys, no proxies | Proposed | M3 | Q15 |
| `0026` | Ops Console Frontend Stack: React 18, Vite, Viem | Proposed | M3 | Q9, T6.1b |

Up: [[Project Memory]] · Related: [[Module 1 - PQ Core]], [[Module 3 - Registry & Compliance]]
