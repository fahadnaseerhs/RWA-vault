---
tags: [rwa-vault, m3, understanding]
---
# 03 — AssetRegistry State Machine

ERC-3643 answers "*who* may hold." The **AssetRegistry** answers the other half: "*may a token for this asset exist at all right now?*" It is the on-chain lifecycle of a real-world asset.

> There is **no interface scaffolded for AssetRegistry yet** — only the ERC-3643 suite is in `contracts/src`. Writing `IAssetRegistry.sol` is the first implementation task (see [[M3 Task Board and Todo]] T1). Its shape depends on [[Open Questions for Fahad]] Q4 and Q5.

## The states
```
UNREGISTERED ──register──► PENDING ──admit──► LIVE ──freeze──► FROZEN
                              │                 ▲                 │
                              │                 └─────unfreeze────┘
                              └──reject──► (stays UNREGISTERED / rejected)
```
- **UNREGISTERED** — the asset is unknown to the chain.
- **PENDING** — a provider has submitted metadata (valuation basis, custodian, documents) but the admission predicate has not yet passed.
- **LIVE** — the 4-clause admission predicate passed; a token may be minted and transferred. This is the only state in which minting is allowed.
- **FROZEN** — an agent has suspended the asset (incident, stale valuation, legal hold); transfers/mints blocked until unfrozen.

## The 4-clause admission predicate
`PENDING → LIVE` is allowed **only if all four hold** (formalised in [[Mathematics - Admission Predicate and Invariants]]):

1. **Signature valid** — the custodian's reserve attestation is a correctly ML-DSA-65-signed M2 envelope from a trusted custodian key.
2. **Sequence increasing** — the attestation's sequence number is strictly greater than the last accepted one (anti-replay, mirrors M2's nonce rule).
3. **Reserve ≥ intended supply** — the attested reserve covers the supply the provider wants to mint.
4. **Valuation fresh** — the valuation timestamp is within the freshness window (not stale).

## The invariant that never breaks
On **every** mint and **every** new attestation:
```
attestedSupply ≤ reserveAmount
```
You can never have more tokens outstanding than the reserve backing them. This is the single most important safety property of the whole asset layer, and it is a Foundry invariant test.

## The open seam
Where does `reserveAmount` and "valuation fresh" come from **in M3**, when the M5 Oracle/Proof-of-Reserve does not exist yet? Either stub it now and wire M5 later, or block M3 on M5. This is [[Open Questions for Fahad]] Q5 and it decides whether M3 can finish inside Sprint 3.

Prev: [[02 - The Three Registries and ONCHAINID]] · Next: [[04 - What's Been Built]] · Up: [[Module 3 - Registry & Compliance]]
