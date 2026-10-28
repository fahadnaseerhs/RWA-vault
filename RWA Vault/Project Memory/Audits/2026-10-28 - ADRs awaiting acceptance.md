# ADRs awaiting acceptance (2026-10-28)

ADR 0001 is the only Accepted record. The other 26 (0002–0027) are **Proposed**. Under ADR 0001, "Proposed" means
the decision can still be edited in place by anyone, agents included. "Accepted" means it is frozen: changing it later
takes a new ADR that supersedes it. Accepting doesn't change any code. It just stops the decisions you've already
taken from drifting (ADR 0020 was edited in place exactly this way).

**What "built" means below:** ✅ the code on disk already follows it · ⏳ nothing is built yet, so accepting it locks the
plan · ⚠️ accept it, but something needs a small fix first or alongside.

## Module 1 — PQ core (already built on these)

| ADR | What it decides, in plain words | Built | Watch out for |
|---|---|---|---|
| 0002 | The project uses six PQ algorithms (Falcon-512, ML-DSA-44/65, SLH-DSA-128s, ML-KEM-768/1024), all owned by M1 | ✅ | — |
| 0003 | The C code comes from PQClean, vendored and pinned. SLH-DSA comes from the pure-Rust `slh-dsa` crate | ✅ | The Build Plan .docx still says liboqs. The ADR wins |
| 0004 | The browser build is `wasm32-unknown-unknown`, with a small C shim we own | ✅ | — |
| 0005 | Servers use an N-API addon (napi-rs), and offline work uses a separate `pqctl` CLI | ✅ | — |
| 0006 | The exact byte layout of keys, signatures and algorithm IDs | ✅ | — |
| 0007 | Randomness comes from the OS natively and from Web Crypto in the browser. With no randomness it fails closed, never falls back | ✅ | — |
| 0008 | The supported platforms and the CI matrix, with runners pinned to `ubuntu-24.04` / `windows-2022` | ⚠️ | `ci.yml` uses `ubuntu-latest` / `windows-latest`. Accept the ADR and pin the runners (a 2-line fix) |
| 0009 | Which official test vectors (NIST ACVP and KATs) count as "conformance" | ✅ | — |
| 0010 | Three fixed benchmark environments and how to measure on them | ✅ | — |
| 0011 | The on-chain Falcon verifier is ETHFALCON, pinned to one commit | ⏳ | M1 Stage 6 isn't built. Accepting locks the pin |

## Module 3 — Registry & Compliance (you decided these as Q1–Q16)

| ADR | What it decides, in plain words | Your Q | Built | Watch out for |
|---|---|---|---|---|
| 0012 | Vendor Tokeny's `onchain-id` for identities. We build the token, registries and compliance ourselves | Q1 | ⏳ | — |
| 0013 | Investor KYC claims stay normal ECDSA. Post-quantum signatures guard only the custodian's reserve attestation | Q3 | ⏳ | — |
| 0014 | "Is the asset live?" is checked by a compliance module, not inside the token | Q4 | ⏳ | It says the module blocks "mint **or transfer**". ADR 0019 §6 later narrowed this to **mints only**. A note in 0014 already points there; accept 0014 as "partly superseded by 0019 §6" |
| 0015 | The mandatory agent powers (forced transfer, burn, recovery) exist but are governed: multisig, timelock, and the key tiers | Q7, Q10 | ✅ interface | — |
| 0016 | One token per asset. Identity storage is shared, so one KYC covers every asset | Q8 | ✅ interface | — |
| 0017 | Reserve data reaches the registry through `IReserveAttestationSource`. For MS1 it's fed straight from the signed custodian envelope, and in Phase 2 M5 plugs into the same interface | Q5 | ✅ interface | I held this one back because Q17/Q18 could change it. They didn't: Q17 kept 4 clauses, and Q18 went into its own ADR 0027. **It's safe to accept now** |
| 0018 | Reserve freshness window τ = 24 h, set at deploy time (never a hard-coded constant), max 365 days | Q13 | ✅ interface | — |
| 0019 | Admission rules: a failed admission reverts and the asset stays PENDING, re-attesting a LIVE asset keeps it LIVE, the agent freezes, the 2-of-3 owner unfreezes, and FROZEN blocks minting only | Q14, Q16 | ✅ interface | Its sections are numbered 1,2,3,4,6,5. That's cosmetic, so it's left as is |
| 0020 | 1 token = 1 gram of **fine** gold, 18 decimals. A 999.9-fine kilobar = `999.9e18` | — | ✅ T6.0 | — |
| 0021 | A stale reserve attestation freezes **minting only**. Transfers, borrows and repayments continue | — | ⏳ | The code comment that said otherwise was fixed on 2026-10-28 |
| 0022 | The platform never holds money. The fiat rail is just a seam to a licensed on-ramp | — | ⏳ | — |
| 0023 | Redemption is cash-settled. Physical delivery is written up but not built | — | ⏳ | — |
| 0024 | A token is fractional title to one identified bar (serial, weight, purity) | — | ⏳ | — |
| 0025 | M3 contracts are immutable: plain deploys, no proxies | Q15 | ⏳ | — |
| 0026 | The ops console is React 18 + Vite + viem. The Foundry script comes first and the UI wraps it | Q9, Q12 | ⏳ | — |
| 0027 | For MS1 the custodian's ML-DSA-65 signature is checked off-chain. A trusted submitter posts the result and M9 anchors the envelope hash | Q18 | ⏳ | Written 2026-10-28. On-chain, clause 1 trusts the submitter, and the ADR says so openly |

## Recommendation

**Accept all 26 (0002–0027).** Mark 0014 "partly superseded by 0019 §6", and pin the CI runners for 0008 in the same
change. Nothing here contradicts the code, and everything left unbuilt is a plan you've already chosen.

## The licence question (bundled with Q21)

The README badge says **Proprietary**, but every contract file starts `SPDX-License-Identifier: GPL-3.0` and the
Decisions Log calls GPL-3.0 locked. The two can't both be true, because GPL code can't sit inside a proprietary repo.
**Recommendation:** GPL-3.0 for `contracts/`, and fix the README badge to match.
