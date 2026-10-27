---
tags: [rwa-vault, stack]
---
# Tech Stack

| Layer        | Choice                                                                                                   |
| ------------ | -------------------------------------------------------------------------------------------------------- |
| Contracts    | Solidity 0.8.26 + Foundry                                                                                |
| Backend      | NestJS on Node (Node 22 LTS, see `.nvmrc`)                                                               |
| Frontend     | React 18 PWA                                                                                             |
| Data         | PostgreSQL 16, Redis 7                                                                                   |
| PQ crypto    | Rust crate over vendored PQClean C + `slh-dsa`; native (N-API via napi-rs) and WASM (`wasm32-unknown-unknown`) |
| Package mgr  | pnpm workspaces                                                                                          |
| Eval harness | Python 3.12+                                                                                             |
| Chain        | Arbitrum Sepolia                                                                                         |

Note: the original plan listed liboqs/WASM; ADR 0003 replaced it with vendored PQClean. See [[ADR Index]].

Related: [[Repo Layout]]
