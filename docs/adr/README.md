# Architecture Decision Records (ADR Index)

One Markdown file per named design decision, numbered sequentially, immutable once accepted.
The format and the rules governing this log are defined in [0001-record-format.md](0001-record-format.md).

| #                                                   | Title                                                               | Status   | Module | Answers / Scope        |
| --------------------------------------------------- | ------------------------------------------------------------------- | -------- | ------ | ---------------------- |
| [0001](0001-record-format.md)                       | Architecture decision record format                                 | Accepted | M0     | Meta                   |
| [0002](0002-pq-primitive-inventory.md)              | The PQ primitive inventory is six, and M1 owns all six              | Accepted | M1     | Crypto Inventory       |
| [0003](0003-pq-implementation-sources.md)           | PQ implementation sources: vendored PQClean C, plus slh-dsa Rust    | Accepted | M1     | Implementation Sources |
| [0004](0004-wasm-build-target.md)                   | Browser WASM target: `wasm32-unknown-unknown` with C shim           | Accepted | M1     | Client Signing         |
| [0005](0005-native-node-bridge.md)                  | Native Node bridge: N-API addon via napi-rs + offline CLI           | Accepted | M1     | Server Runtime         |
| [0006](0006-byte-encoding-contract.md)              | The M1 byte encoding contract                                       | Accepted | M1     | Wire Protocol          |
| [0007](0007-random-source.md)                       | Random source: OS CSPRNG natively, Web Crypto in WASM               | Accepted | M1     | Entropy                |
| [0008](0008-target-platforms-and-ci.md)             | Supported platforms and the M1 CI matrix                            | Accepted | M1     | Target CI              |
| [0009](0009-test-vector-inventory.md)               | Test-vector inventory and what "conformance" means                  | Accepted | M1     | ACVP / KAT             |
| [0010](0010-benchmark-environments.md)              | Benchmark reference environments and measurement protocol           | Accepted | M1     | Benchmarks             |
| [0011](0011-ethfalcon-verifier-pin.md)              | ETHFALCON: pin the commit, and use NIST-compliant verifier          | Accepted | M1     | On-chain Falcon        |
| [0012](0012-hybrid-erc3643-implementation.md)       | Hybrid ERC-3643: vendor `onchain-id`, build registries & compliance | Accepted | M3     | Q1                     |
| [0013](0013-claims-ecdsa-pq-at-reserve.md)          | Investor claims stay ECDSA; PQ guards the reserve attestation       | Accepted | M3     | Q3                     |
| [0014](0014-asset-liveness-as-compliance-module.md) | Asset liveness is a compliance module, not a token check            | Accepted | M3     | Q4                     |
| [0015](0015-agent-powers-and-key-tiers.md)          | Agent powers governed; roles mapped to PQ key tiers                 | Accepted | M3     | Q7, Q10                |
| [0016](0016-one-token-per-asset.md)                 | One ERC-3643 token per asset, with shared identity storage          | Accepted | M3     | Q8                     |
| [0017](0017-reserve-attestation-source-seam.md)     | Reserve data reaches M3 through a stubbed interface seam            | Accepted | M3     | Q5                     |
| [0018](0018-valuation-freshness-window.md)          | Valuation freshness window: 24 hours for gold, set not compiled     | Accepted | M3     | Q13                    |
| [0019](0019-asset-admission-state-semantics.md)     | Asset admission and freeze semantics in the AssetRegistry           | Accepted | M3     | Q14, Q16               |
| [0020](0020-token-unit-is-one-gram.md)              | One token is one fine gram of gold ($10^{18}$ base units)           | Accepted | All    | C5                     |
| [0021](0021-stale-reserve-freezes-minting-only.md)  | A stale reserve attestation freezes minting only                    | Accepted | M3/M5  | C9                     |
| [0022](0022-no-fiat-custody-onramp-seam.md)         | Platform holds no money: fiat rail is an on-ramp seam               | Accepted | M8     | C7                     |
| [0023](0023-cash-settled-redemption-only.md)        | Redemption is cash-settled; physical delivery specified, not built  | Accepted | M3/M8  | C6                     |
| [0024](0024-fractional-title-to-identified-lot.md)  | A token is fractional title to an identified lot                    | Accepted | All    | C8                     |
| [0025](0025-immutable-deployments.md)               | M3 contracts are immutable: plain deploys, no proxies               | Accepted | M3     | Q15                    |
| [0026](0026-ops-console-frontend-scaffold.md)       | Ops Console Frontend Stack: React 18, Vite, Viem                    | Accepted | M3     | Q9, T6.1b              |
| [0027](0027-clause-one-verified-off-chain.md)       | Clause 1 verified off-chain for MS1; envelope hash anchored         | Accepted | M3     | Q18                    |

> **Protocol Rule:** Numbers 0001–0027 are fully allocated. The next ADR must be claimed as `0028` via file creation.
