---
tags: [rwa-vault, overview]
---
# Overview

RWA-Vault is a **Final Year Project**: a post-quantum anchored protocol for tokenised real-world assets (RWA) with collateralised micro-liquidity at the **PKR 1,000 scale**.

## The problem
Every deployed RWA protocol authenticates with ECDSA, which Shor's algorithm breaks.

## The idea
Separate **authentication** from **anchoring**:
- PQ signatures are verified **off-chain**.
- Only a **Merkle root** is anchored on-chain per epoch (~43k gas per 60 s epoch).
- Past roughly **14 events per epoch**, PQ auth becomes cheaper than per-event ECDSA.

## Posture
Sandbox only: mock settlement, test-net tokens, **no real funds**. Target chain is **Arbitrum Sepolia**.

## Key standards
- **ERC-3643** — restricted (permissioned) ownership
- **ERC-4626** — vault accounting, with a virtual-share offset
- **Aave V3 patterns** — health factor, scaled debt index
- **Oracle** — 5 sources, median + TWAP gate

Related: [[Tech Stack]], [[Roadmap & Milestones]]
