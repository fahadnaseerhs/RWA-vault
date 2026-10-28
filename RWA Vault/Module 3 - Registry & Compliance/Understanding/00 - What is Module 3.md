---
tags: [rwa-vault, m3, understanding]
---
# 00 — What is Module 3

## The one-sentence version
Module 3 is the layer that makes a tokenised real-world asset **permissioned**: the token can only be held and moved by wallets that a trusted party has verified, and only while the asset behind it is in good standing.

## The problem it solves
After M1 (PQ crypto) and M2 (who holds which key, and signed envelopes), we can prove *who did something*. But a plain ERC-20 lets **anyone** receive tokens. For a regulated real-world asset — a gold lot, a property share — that is illegal and unsafe. We need:

1. A way to say **"this wallet belongs to a verified investor"** and refuse everyone else.
2. A way to tie the token's existence to the **asset actually being registered and reserved** — you cannot mint 100 tokens of gold against 80 grams of reserve.
3. **Controls** for an operator: freeze a compromised wallet, pause the whole token in an incident, force a transfer or recover tokens for a legal/recovery reason.

Module 3 delivers all three, on-chain, using the **ERC-3643 (T-REX)** standard for the first and third, and an **AssetRegistry state machine** for the second.

## Where it sits
```
M1 PQ Core ──► M2 PQ-PKI & Envelope ──► M3 Registry & Compliance ──► M4 Vault Accounting
                      │                        │
             signed attestations        the token + the gate
             (ML-DSA-65 envelopes)       (who can hold, is it LIVE)
```
M3 **consumes** M2: the custodian's reserve attestation arrives as an ML-DSA-65-signed envelope, and M3's admission predicate verifies it before an asset can go LIVE. M3 **feeds** M4 (vault accounting operates on the M3 token) and the **MS1 milestone** (a gold lot registered *and tokenised* against an attested reserve).

## The two halves of M3
- **ERC-3643 permissioning** — the token + Identity Registry + ONCHAINID + Modular Compliance. "*Who* may hold, and *is this movement* allowed." → [[01 - ERC-3643 in Plain Words]], [[02 - The Three Registries and ONCHAINID]]
- **AssetRegistry** — the asset's lifecycle and the 4-clause admission predicate. "*Does the asset itself* permit a token to exist right now." → [[03 - AssetRegistry State Machine]]

A big open design question is **how these two halves connect** — is "asset is LIVE" a compliance module, or a mint-time check? See [[Open Questions for Fahad]] Q4.

Next: [[01 - ERC-3643 in Plain Words]] · Up: [[Module 3 - Registry & Compliance]]
