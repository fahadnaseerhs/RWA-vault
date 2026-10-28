---
tags: [rwa-vault, m3, understanding]
---
# 02 — The Three Registries and ONCHAINID

The gate in [[01 - ERC-3643 in Plain Words]] is answered by four contracts working together. Here is how a single `isVerified(wallet)` call flows through them.

## The flow
```
token.transfer(to) ──► IdentityRegistry.isVerified(to)
                              │
          1. identity = storage.storedIdentity(to)      (wallet → ONCHAINID)
          2. topics   = ClaimTopicsRegistry.getClaimTopics()
          3. for each topic t in topics:
                 issuers = TrustedIssuersRegistry.getTrustedIssuersForClaimTopic(t)
                 claim   = identity.getClaim(... from one of `issuers` ...)
                 require claim exists, not revoked, signature valid
          4. all topics satisfied ⇒ verified
```

## The four pieces
### 1. Identity Registry (`IIdentityRegistry`)
The front door. `registerIdentity(wallet, onchainID, country)`, `deleteIdentity`, `isVerified`. Emits `IdentityRegistered`, `CountryUpdated`, etc. The token calls `isVerified` on **every** mint and transfer.

### 2. Identity Registry **Storage** (`IIdentityRegistryStorage`)
Separates *storage* from *logic* so several tokens can share one set of registered investors. Holds the `wallet → identity` and `wallet → country` maps. For the FYP you may collapse this into the registry, or keep it split (standard T-REX keeps it split) — noted in [[Open Questions for Fahad]] Q1.

### 3. Claim Topics Registry (`IClaimTopicsRegistry`)
The *policy*: the set of topics an investor must hold. Example topic numbering (ours to choose):
- `1` = KYC passed
- `2` = accredited / eligible investor
- `3` = country allow-listed
**How many topics, and which, is a decision** — see [[Open Questions for Fahad]] Q2.

### 4. Trusted Issuers Registry (`ITrustedIssuersRegistry`)
The *trust*: which issuer addresses may sign which topics. A claim for topic 1 only counts if it came from an issuer trusted for topic 1. In the FYP the issuer is likely a single project-run KYC service — and **how that issuer ties into the M2 PQ attestation is Q3**.

## ONCHAINID (`IIdentity` = ERC-734 keys + ERC-735 claims)
A per-investor smart contract.
- **ERC-734 (`IERC734`)** — a key manager: keys with purposes (management / action / claim-signer) and types. This is *on-chain key management for the identity itself* — distinct from our M2 PQ key registry, which manages the project's operational PQ keys. Keeping these two mental models separate matters.
- **ERC-735 (`IERC735`)** — claims: `(topic, scheme, issuer, signature, data, uri)`. A claim is a trusted issuer's signed statement "this identity satisfies topic X."
- **`IClaimIssuer`** — an issuer contract that can also *revoke* a claim and answer `isClaimValid`.

> The deep question: **do we build our own minimal ONCHAINID, or vendor Tokeny's `onchain-id` + T-REX?** That is [[Open Questions for Fahad]] Q1 and it shapes how much we write by hand.

Prev: [[01 - ERC-3643 in Plain Words]] · Next: [[03 - AssetRegistry State Machine]] · Up: [[Module 3 - Registry & Compliance]]
