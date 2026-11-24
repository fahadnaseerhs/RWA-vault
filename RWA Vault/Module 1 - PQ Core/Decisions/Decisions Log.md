---
tags: [rwa-vault, m1, decisions]
updated: 2026-11-22
---
# M1 Decisions Log

A running record of decisions made for M1. Open items live in [[Open Questions for Fahad]]. The ADR is the source of truth; dates and reasoning are in each ADR file.

## Decided (ADR-only, no Question note)

| ADR | Decision | ADR status |
|---|---|---|
| [[ADR Index\|0002]] | The PQ primitive inventory is six, and M1 owns all six | Accepted |
| [[ADR Index\|0003]] | PQ implementation sources: vendored PQClean C + pure Rust | Accepted |
| [[ADR Index\|0004]] | Browser WASM target: `wasm32-unknown-unknown` with C shim | Accepted |
| [[ADR Index\|0005]] | Native Node bridge: N-API addon via napi-rs + CLI | Accepted |
| [[ADR Index\|0006]] | The M1 byte encoding contract | Accepted |
| [[ADR Index\|0007]] | Random source: OS CSPRNG natively, Web Crypto in WASM | Accepted |
| [[ADR Index\|0008]] | Supported platforms and M1 CI matrix | Accepted |
| [[ADR Index\|0009]] | Test-vector inventory and what "conformance" means | Accepted |
| [[ADR Index\|0010]] | Benchmark reference environments and measurement protocol | Accepted |
| [[ADR Index\|0011]] | ETHFALCON: pin the commit, and use NIST-compliant verifier | Accepted |

## Decided (Question notes)

| Question | Decision | Decided |
|---|---|---|
| [[Questions/Q01 - Where do the prebuilt addon binaries live\|Q01]] | D — no prebuilds for MS1; Rust mandatory; S3-05 descoped | 2026-11-22, Fahad Naseer |
| [[Questions/Q02 - Does the contract test run in Node only\|Q02]] | A — contract-equivalence test runs in Node only | 2026-11-22, Fahad Naseer |
| [[Questions/Q03 - SLH-DSA signing split across adapters\|Q03]] | B — keep native/WASM SLH-DSA sign split; S3-10 encodes it; fix deferred | 2026-11-24, Fahad Naseer |

Up: [[Module 1 - PQ Core]] · Related: [[Open Questions for Fahad]], [[ADR Index]]
