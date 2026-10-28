---
tags: [rwa-vault, m3, algorithms, mathematics]
---
# Mathematics — Admission Predicate and Invariants

The formal core of M3. Everything the contracts enforce reduces to the predicates and invariants below. These are what the Foundry tests assert.

---

## 1. Verification predicate (`isVerified`)
Let a wallet be $w$, its linked identity $\mathrm{id}(w)$, the required topic set $T = \{t_1,\dots,t_n\}$ from the Claim Topics Registry, and $\mathrm{Trusted}(t)$ the set of issuer addresses trusted for topic $t$.

A claim is a tuple $c = (\text{topic}, \text{issuer}, \sigma, \text{data})$. Define claim validity:
$$
\mathrm{valid}(c) \;\equiv\; \neg\mathrm{revoked}(c)\;\wedge\;\mathrm{SigOK}(\text{issuer},\sigma,\text{data})
$$

Then the wallet is verified iff **every required topic is covered by at least one valid claim from a trusted issuer**:
$$
\mathrm{isVerified}(w)\;\equiv\;\forall\, t\in T\;\;\exists\, c\in \mathrm{claims}(\mathrm{id}(w)):\;\; c.\text{topic}=t \;\wedge\; c.\text{issuer}\in\mathrm{Trusted}(t)\;\wedge\;\mathrm{valid}(c)
$$
Empty $T$ ⇒ vacuously true, so **never ship with an empty topic set** (it disables the gate). Enforce $|T|\ge 1$.

The token's transfer guard is then:
$$
\mathrm{canMove}(from,to,amt)\;\equiv\;\mathrm{isVerified}(to)\;\wedge\;\neg\mathrm{frozen}(from)\;\wedge\;\neg\mathrm{paused}\;\wedge\;\mathrm{compliance}.\mathrm{canTransfer}(from,to,amt)
$$
(On `mint`, $from=\varnothing$ and the `frozen(from)` term drops.)

---

## 2. The 4-clause admission predicate (PENDING → LIVE)
An attestation is $a = (\text{assetId}, \text{reserve}, \text{seq}, \text{valuationTs}, \sigma, \text{custodianKey})$. Let $S$ = intended supply, $\mathrm{seq}_{\text{last}}$ = last accepted sequence for the asset, $\tau$ = freshness window, and $\mathrm{now}$ = block time.

$$
\mathrm{admit}(a, S)\;\equiv\;
\underbrace{\mathrm{VerifyPQ}(a.\text{custodianKey}, a.\sigma, a)}_{\text{(1) signature valid}}
\;\wedge\;
\underbrace{a.\text{seq} > \mathrm{seq}_{\text{last}}}_{\text{(2) sequence increasing}}
\;\wedge\;
\underbrace{a.\text{reserve} \ge S}_{\text{(3) reserve} \ge \text{supply}}
\;\wedge\;
\underbrace{\mathrm{now} - a.\text{valuationTs} \le \tau}_{\text{(4) valuation fresh}}
$$

- **(1)** uses ML-DSA-65 via the M2 verifier (⛔ depends on M2 readiness; see [[Open Questions for Fahad]] Q3).
- **(2)** mirrors the M2 nonce rule — strictly increasing, so a replayed older attestation is refused.
- **(4)** $\tau$ must be chosen (e.g. 24h). Too large ⇒ stale valuations slip through; too small ⇒ false freezes. **Pick and record $\tau$** (ADR).

On success: $\mathrm{seq}_{\text{last}} \leftarrow a.\text{seq}$, $\mathrm{reserve}(\text{assetId}) \leftarrow a.\text{reserve}$, state $\leftarrow$ LIVE.

---

## 3. The master invariant
For every asset, at **all times**, across every mint, burn, and re-attestation:
$$
\boxed{\;\mathrm{attestedSupply}(\text{assetId}) \;\le\; \mathrm{reserve}(\text{assetId})\;}
$$
Equivalently, a mint of $m$ is permitted iff $\mathrm{attestedSupply} + m \le \mathrm{reserve}$. This is the single safety property that makes the token "backed." It is a **Foundry invariant test** (T4.5): the fuzzer may mint/burn/re-attest in any order and the property must always hold.

Corollary (re-attestation down): if a new attestation lowers reserve below current supply, the asset **cannot** silently become under-collateralised — either the lower attestation is refused, or the asset moves to FROZEN and minting halts. Decide which (recommend: accept the lower reserve, block new mints, flag for freeze) and encode it as a test.

---

## 4. State machine as a relation
States $Q = \{\text{UNREGISTERED}, \text{PENDING}, \text{LIVE}, \text{FROZEN}\}$. The only legal transitions:
$$
\begin{aligned}
&\text{UNREGISTERED} \xrightarrow{\text{register}} \text{PENDING}\\
&\text{PENDING} \xrightarrow{\text{admit}=\top} \text{LIVE} \qquad \text{PENDING} \xrightarrow{\text{admit}=\bot} \text{UNREGISTERED/rejected}\\
&\text{LIVE} \xrightarrow{\text{freeze}} \text{FROZEN} \qquad \text{FROZEN} \xrightarrow{\text{unfreeze}} \text{LIVE}
\end{aligned}
$$
Minting is permitted **iff** state $=$ LIVE. Any other transition attempt reverts. This is a total function on $(Q, \text{action})$ — every undefined pair is a revert, asserted in tests.

---

## 5. What the tests must assert (map to code)
| Property | Test |
| -------- | ---- |
| §1 isVerified correctness | `test_RegistryVerificationMatchesHolders` + unit tests on revoked/wrong-issuer claims |
| §1 canMove gate | the 6 acceptance tests in `ERC3643Acceptance.t.sol` |
| §2 each admission clause independently | one unit test per clause failing in isolation (like M2's "fail at the named check") |
| §3 master invariant | Foundry `invariant_attestedSupplyLeReserve` |
| §4 illegal transitions revert | one test per undefined (state, action) pair |

> Style rule carried from M1: tests assert the **exact** revert/error, never a bare `is_err()` / unspecified `expectRevert()`. Give each admission-clause failure a named custom error.

Up: [[Module 3 - Registry & Compliance]] · Related: [[03 - AssetRegistry State Machine]], [[Decision Algorithms - for Fahad]]
