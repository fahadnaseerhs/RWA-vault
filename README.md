# RWA-Vault

> **A Post-Quantum Secured Programmable Wealth Platform for Tokenized Real World Assets**

[![CI](https://github.com/fahadnaseerhs/RWA-vault/actions/workflows/ci.yml/badge.svg)](https://github.com/fahadnaseerhs/RWA-vault/actions/workflows/ci.yml)
[![Node 22 LTS](https://img.shields.io/badge/node-22.16.0%20LTS-brightgreen.svg)](.nvmrc)
[![pnpm 9](https://img.shields.io/badge/pnpm-9.12.0-orange.svg)](package.json)
[![Rust 1.81](https://img.shields.io/badge/rust-1.81.0-blue.svg)](packages/pq-core/native/rust-toolchain.toml)
[![Arbitrum Sepolia](https://img.shields.io/badge/network-Arbitrum%20Sepolia-blueviolet.svg)](https://sepolia.arbiscan.io/)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)

- **Technical Proposal:** [`docs/RWA-Vault_proposal_v2.pdf`](docs/RWA-Vault_proposal_v2.pdf)
- **Module Build Plan:** [`docs/RWA-Vault_Module_Build_Plan.docx`](docs/RWA-Vault_Module_Build_Plan.docx)
- **Developer Guide:** [`CONTRIBUTING.md`](CONTRIBUTING.md)
- **Obsidian Project Vault:** [`RWA Vault/`](RWA%20Vault/)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture & System Flow](#2-architecture--system-flow)
3. [Developer Onboarding & What's in CONTRIBUTING.md](#3-developer-onboarding--whats-in-contributingmd)
4. [Current Implementation: Module 1 (PQ Core)](#4-current-implementation-module-1-pq-core)
5. [Roadmap & 12-Module Dependency Matrix](#5-roadmap--12-module-dependency-matrix)
6. [Quickstart: Zero-Install & Local Paths](#6-quickstart-zero-install--local-paths)
7. [Running & Verification Commands](#7-running--verification-commands)
8. [Repository Layout](#8-repository-layout)
9. [CI Quality Gates](#9-ci-quality-gates)
10. [Academic Research Posture](#10-academic-research-posture)

---

## 1. Executive Summary

### The Problem
Existing Real World Asset (RWA) tokenization platforms authenticate custody transfers and financial transactions using traditional elliptic-curve signatures (ECDSA / Ed25519). Shor's algorithm on cryptanalytically relevant quantum computers will break these schemes. However, running post-quantum signatures natively on-chain (e.g. EVM) is computationally prohibitive: a single Falcon or Dilithium verification can consume tens or hundreds of thousands of gas units.

### The Solution: Separate Authentication from Anchoring
RWA-Vault resolves this tension with a **hybrid post-quantum settlement model**:
1. **Off-Chain PQ Authentication:** Users, oracles, custodians, and vault managers sign transactions using NIST-standardized Post-Quantum Cryptography (FIPS 203 ML-KEM, FIPS 204 ML-DSA, FIPS 205 SLH-DSA, and Falcon-padded-512). Signing and verification run natively in backend services (`napi-rs` Node addon) and client browsers (`wasm32-unknown-unknown`).
2. **On-Chain Periodic Merkle Anchoring:** An off-chain batcher accumulates PQ-signed actions over 60-second epochs into an immutable Merkle tree. Only the resulting **32-byte Merkle root** is anchored on **Arbitrum Sepolia** at a fixed, predictable cost (~43,000 gas per epoch). Beyond 14 actions per epoch, post-quantum authentication becomes cheaper than per-event ECDSA.
3. **Optimistic Dispute Verifier:** Falcon signatures are anchored into state transitions, with an on-chain `ETHFALCON` dispute contract ready to penalize invalid transitions under fraud-proof challenges.

---

## 2. Architecture & System Flow

```
+----------------------------------------------------------------------------------+
|                                CLIENT LAYER (M10)                                |
|  Borrower & Lender PWA (React 18 + viem)    |    Operations & Custodian Console  |
|  - Client-side keygen & signing via WASM    |    - In-browser key management     |
+----------------------------------------+-----------------------------------------+
                                         | Post-Quantum Signed Requests
                                         v
+----------------------------------------------------------------------------------+
|                               SERVICES LAYER (M5-M9)                             |
|  pq-verifier (M2)  <-- Stateless 7-condition verification                        |
|  settlement-rail (M8) <-- Double-entry ledger (PKR 1,000 scale)                  |
|  risk-engine (M6)     <-- Health-factor sweep on Redis Streams                   |
|  oracle (M5)          <-- 5-source price median + TWAP gate                      |
|  anchor-batcher (M9)  <-- 60s Merkle epoch aggregator                            |
+----------------------------------------+-----------------------------------------+
                                         | Node-API (napi-rs) Addon
                                         v
+----------------------------------------------------------------------------------+
|                                PACKAGES LAYER (M1-M2)                            |
|  packages/pq-core: Vendored PQClean C + Rust + WebAssembly + TypeScript API      |
|  packages/envelope-codec: Seven-field canonical envelope serialization           |
+----------------------------------------+-----------------------------------------+
                                         | Merkle Root (~43k gas / 60s)
                                         v
+----------------------------------------------------------------------------------+
|                            ON-CHAIN LAYER (Arbitrum Sepolia)                     |
|  contracts/registry  <-- ERC-3643 Permissioned Asset Identity                    |
|  contracts/vault     <-- ERC-4626 Vault Accounting (Virtual Share Offset)        |
|  contracts/lending   <-- Aave V3 Collateralized Micro-Lending Pool               |
|  contracts/anchoring <-- Merkle Anchor Root Storage & Epoch Verification         |
+----------------------------------------------------------------------------------+
```

---

## 3. Developer Onboarding & What's in CONTRIBUTING.md

[`CONTRIBUTING.md`](CONTRIBUTING.md) contains the non-negotiable operational conventions for all developers working on RWA-Vault:

| Rule / Section in `CONTRIBUTING.md` | Why it exists & How it works |
| ----------------------------------- | ---------------------------- |
| **Path A: Dev Container** | Recommended setup. Requires only Docker & VS Code. Installs Node, Rust, Foundry, Python and launches Anvil + Postgres + Redis automatically. |
| **Path B: Local Toolchain** | Pins specific tool versions: Node `22.16.0`, pnpm `9.12.0`, Rust `1.81.0`, wasm-pack `0.13.1`, Python `3.12+`, Foundry `stable`. |
| **Clean-Clone Gate** | Any PR must pass `pnpm install && pnpm lint && pnpm typecheck && pnpm build && pnpm test` before merge. |
| **Branching Strategy** | Trunk-based development. Feature branches (`codex/module-<N>`, `feat/<topic>`) merge directly to `main` with two required approvals. |
| **Commit Standard** | Strictly [Conventional Commits](https://www.conventionalcommits.org/): `feat(m1): ...`, `fix(ci): ...`, `docs: ...`. |
| **Interfaces Before Implementations** | Every module must start with an interface-only PR and acceptance test before writing production implementation. |
| **Architecture Decision Records (ADRs)** | Architectural choices are permanently recorded in `docs/adr/`. ADRs are immutable once accepted (supersede, never edit). |
| **Unidirectional Dependency Law** | `packages/` is consumed by `services/` and `apps/`, never the reverse. |

---

## 4. Current Implementation: Module 1 (PQ Core)

Module 1 is currently active on the `codex/module-1` branch. **Stages 0–3 are complete (49 / 102 tasks).**

### Primitive Matrix Delivered
| Algorithm | Scheme | Role in RWA-Vault | Standard |
| --------- | ------ | ----------------- | -------- |
| **Falcon-padded-512** | Signature | Fast client-side signing & on-chain dispute verification | NIST Round 3 |
| **ML-DSA-44** | Signature | Level 2 signing for general transactions & ops | FIPS 204 |
| **ML-DSA-65** | Signature | Level 3 custodian & validator authentication | FIPS 204 |
| **SLH-DSA-SHA2-128s** | Signature | Stateless hash-based root ceremony (`pqctl` CLI only) | FIPS 205 |
| **ML-KEM-768** | KEM | Encrypted envelope key exchange | FIPS 203 |
| **ML-KEM-1024** | KEM | High-security key encapsulation rail | FIPS 203 |

### Stage 3 Deliverables (Runtime Adapters)
- **Node-API Addon (`packages/pq-core/native/napi/`)**: High-performance async wrappers (`AsyncTask`) preventing thread pool starvation on Node 22. Server-side SLH-DSA signing excluded by design (ADR 0005).
- **WebAssembly Adapter (`packages/pq-core/native/src/wasm.rs`)**: Generic `WasmKeyPair` and `WasmEncapsulation` covering all 6 primitives in browser targets.
- **TypeScript API (`packages/pq-core/src/`)**: Shared `PqCoreApi` contract interface, nine `PqError` error classes, and ADR 0006 metadata table.
- **`pqctl` CLI (`packages/pq-core/native/pqctl/`)**: Standalone, air-gapped SLH-DSA root ceremony utility for offline key generation, file signing, and verification.

---

## 5. Roadmap & 12-Module Dependency Matrix

Development spans 4 phases across 13 two-week sprints:

```
M0 (Devnet) ──> M1 (PQ Core) ──> M2 (Envelope & PKI) ──> M3 (Registry) ──> M4 (Vault)
                                       │                        │                │
                                       ├──> M5 (Oracle)         └──> M10 (Apps) <┘
                                       ├──> M8 (Settlement)
                                       └──> M9 (Anchoring) ──> M6 (Risk) ──> M7 (Lending)
                                                                 │
                                                       All ────> M11 (Eval Harness)
```

| Phase | Milestone Gate | Focus |
| ----- | -------------- | ----- |
| **Phase 1: Foundation (Wk 1–6)** | **MS1**: Gold lot registered & tokenized against attested reserve | M0 (Devnet), M1 (PQ Core), M2 (PKI), M3 (Registry), M4 (Vault) |
| **Phase 2: Investment Path (Wk 7–11)** | **MS2**: PKR 5,000 deposit with offline verifiable Merkle proof | M5 (Oracle), M8 (Settlement), M9 (Anchoring) |
| **Phase 3: Lending & Risk (Wk 12–19)** | **MS3**: Collateralized borrow with automated health-factor liquidation | M6 (Risk Engine), M7 (Micro-Lending), M10 (Web Clients) |
| **Phase 4: Evaluation (Wk 20–24)** | **MS4**: Thesis defense; RQ1–RQ4 benchmarks from hardware measurement | M11 (Python evaluation pipeline & charts) |

---

## 6. Quickstart: Zero-Install & Local Paths

### Option A: VS Code Dev Container (Zero Manual Tooling)
1. Install [Docker Desktop](https://www.docker.com/) and [VS Code](https://code.visualstudio.com/).
2. Install the **Dev Containers extension**.
3. Open this folder in VS Code and click **"Reopen in Container"**. All compilers, runtimes, and local Docker databases launch automatically.

### Option B: Local Installation
Ensure the pinned runtimes from the table above are installed, then clone the repository:

```bash
# 1. Clone recursively to fetch contracts/lib git submodules
git clone --recurse-submodules https://github.com/fahadnaseerhs/RWA-vault.git
cd RWA-vault

# 2. Configure environment
cp .env.example .env

# 3. Enable pnpm 9 via Corepack & install dependencies
corepack enable
pnpm install

# 4. Start local Docker devnet (Anvil + PostgreSQL + Redis)
pnpm devnet:up
```

---

## 7. Running & Verification Commands

### Verify Module 1 (Post-Quantum Core)
```bash
# Typecheck and lint TypeScript adapters
cd packages/pq-core
pnpm build
pnpm lint

# Run native Rust unit tests across all 6 primitives
pnpm test:rust

# Run the 6-algorithm interactive walkthrough demo
cargo run --example demo --manifest-path native/Cargo.toml --release

# Run the offline SLH-DSA root ceremony CLI (pqctl)
cargo build --release --manifest-path native/pqctl/Cargo.toml
./native/pqctl/target/release/pqctl keygen --out ./ceremony
./native/pqctl/target/release/pqctl sign   --key ./ceremony/slh-dsa-sha2-128s.key \
                                            --message package.json --out sig.bin
./native/pqctl/target/release/pqctl verify --key ./ceremony/slh-dsa-sha2-128s.pub \
                                            --message package.json --sig sig.bin
```

### Smart Contracts (Foundry)
```bash
pnpm contracts:build         # Compile Solidity contracts
pnpm contracts:test          # Run Foundry unit and fuzz tests (1k runs)
pnpm contracts:snapshot      # Generate gas consumption reports
pnpm contracts:fmt           # Verify contract code formatting
```

### Full Repository Gate
```bash
pnpm lint && pnpm typecheck && pnpm build && pnpm test
```

---

## 8. Repository Layout

```
rwa-vault/
├── apps/
│   ├── client/              # M10  Borrower/lender React 18 PWA
│   └── ops-console/         # M10  Custodian onboarding & audit console
├── contracts/
│   ├── src/                 # Solidity smart contracts (Arbitrum Sepolia)
│   ├── test/                # Forge test suites (unit + invariant fuzzing)
│   └── lib/                 # Submodule dependencies (forge-std, openzeppelin)
├── docs/
│   ├── adr/                 # Architecture Decision Records (0001-0011)
│   ├── RWA-Vault_proposal_v2.pdf
│   └── RWA-Vault_Module_Build_Plan.docx
├── eval/
│   ├── scripts/             # Python 3.12 data analysis for RQ1-RQ4
│   └── requirements.txt     # Locked Python evaluation dependencies
├── infra/
│   └── docker-compose.yml   # Anvil + PostgreSQL 16 + Redis 7 devnet
├── packages/
│   ├── config/              # Shared ESLint, Prettier, and TS base configs
│   ├── envelope-codec/      # M2  PQ-signed envelope encode/decode (TS)
│   ├── pq-core/             # M1  Rust PQClean native + WASM + napi addon
│   └── types/               # Canonical shared domain types & ABI interfaces
├── services/
│   ├── anchor-batcher/      # M9  60-second epoch Merkle tree batching
│   ├── oracle/              # M5  5-source median + TWAP price consumer
│   ├── pq-verifier/         # M2  Stateless 7-condition envelope verifier
│   ├── risk-engine/         # M6  Health factor sweep on Redis Streams
│   └── settlement-rail/     # M8  Mock PKR 1,000 double-entry ledger
└── RWA Vault/               # Obsidian project memory & knowledge base
```

---

## 9. CI Quality Gates

GitHub Actions runs three parallel workflows on every push and pull request:
1. **`node` Job:** Runs `pnpm lint`, `pnpm typecheck`, `pnpm build`, `pnpm test`, and Prettier format verification.
2. **`contracts` Job:** Compiles Solidity sources and executes 1,000 fuzz runs.
3. **`contracts-invariants` Job:** Executes deep 1,000,000-run property-based invariant tests.

---

## 10. Academic Research Posture

RWA-Vault is developed as a University Final Year Project evaluating post-quantum cryptographic feasibility in decentralized finance. All settlement rails operate in mock sandbox mode targeting the **Arbitrum Sepolia** testnet. **No real-world financial funds are deployed or at risk.**
