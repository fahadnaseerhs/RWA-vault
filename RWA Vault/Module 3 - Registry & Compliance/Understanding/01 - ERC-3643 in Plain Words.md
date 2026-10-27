---
tags: [rwa-vault, m3, understanding]
---
# 01 — ERC-3643 in Plain Words

ERC-3643 (also called **T-REX**, "Token for Regulated EXchanges") is an ERC-20 with a permission gate welded on. Every `mint` and `transfer` first asks two questions:

1. **Is the receiver allowed to hold this token?** → asked to the **Identity Registry**.
2. **Is this specific movement compliant?** → asked to the **Modular Compliance** contract.

If either says no, the transfer reverts. That is the entire idea.

## The moving parts (all scaffolded as interfaces)
| Contract | Plain-words job |
| -------- | --------------- |
| **Token** (`IERC3643`) | The ERC-20 itself. Overrides `transfer`/`mint` to call the gate. Adds agent powers: `pause`, `setAddressFrozen`, `freezePartialTokens`, `forcedTransfer`, `burn`, `recoveryAddress`, and batch versions. |
| **Identity Registry** (`IIdentityRegistry`) | Maps a wallet → an identity contract, and answers `isVerified(wallet)`. |
| **Identity Registry Storage** | The actual storage behind the registry (so multiple tokens can share one identity set). |
| **Claim Topics Registry** | The list of claim topics an investor *must* have (e.g. KYC = topic 1). |
| **Trusted Issuers Registry** | Which issuer addresses are allowed to sign which claim topics. |
| **ONCHAINID** (`IIdentity`, ERC-734/735) | A per-investor identity contract holding **keys** (ERC-734) and **claims** (ERC-735). |
| **Modular Compliance** (`IModularCompliance`) | Holds a list of pluggable **modules** (`IModule`); each can veto a transfer. |

## The two roles
- **Owner** — sets configuration: name, symbol, the identity registry, the compliance contract. Think "deployer / governance."
- **Agent** — runs operations: mint, burn, freeze, pause, forced transfer, recovery. Think "the operator."

> Mapping these two roles onto our **M2 three-tier PQ key hierarchy** is an open decision — see [[Open Questions for Fahad]] Q7.

## `isVerified` — the heart of it
A wallet is verified **iff** its linked ONCHAINID holds, for **every** topic in the Claim Topics Registry, at least one claim that is (a) issued by an address trusted for that topic, and (b) not revoked, and (c) valid (signature checks out). Formalised in [[Mathematics - Admission Predicate and Invariants]].

## Why not just a normal ERC-20 with an allowlist?
A flat allowlist can't express "verified by a trusted KYC issuer for these topics," can't carry a portable identity across tokens, and can't be audited the way claims can. ERC-3643 is the de-facto standard for regulated tokens, so using it makes the FYP credible and the acceptance test meaningful.

Prev: [[00 - What is Module 3]] · Next: [[02 - The Three Registries and ONCHAINID]] · Up: [[Module 3 - Registry & Compliance]]
