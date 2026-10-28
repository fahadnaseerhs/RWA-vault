---
tags: [rwa-vault, m3, algorithms, fahad]
---
# Decision Algorithms — for Fahad

The runnable decision trees for M3. Where [[Mathematics - Admission Predicate and Invariants]] gives the *formal* predicates, this note gives the **step-by-step flows** a human (or the operator service) follows. Use these to sanity-check behaviour and to script the demo. They assume the recommended answers in [[Open Questions for Fahad]]; adjust if a decision differs.

---

## A. Onboard a gold lot (provider flow)
```
START: provider has a physical gold lot + a custodian
 1. Collect metadata: assetId, description, valuation basis, custodian id, intended supply S
 2. Register asset  → state goes UNREGISTERED → PENDING
 3. Ask custodian for a reserve attestation:
       a = (assetId, reserve, seq, valuationTs), signed ML-DSA-65  (M2 envelope)
 4. Submit a to AssetRegistry.admit(assetId, S):
       ┌─ signature valid?            no → REJECT (error: BadAttestationSig)
       ├─ seq > last seq?             no → REJECT (error: StaleSequence)
       ├─ reserve ≥ S?                no → REJECT (error: ReserveTooLow)
       └─ now − valuationTs ≤ τ?      no → REJECT (error: ValuationStale)
       all yes → state PENDING → LIVE, store reserve, bump seq
 5. Deploy / assign the ERC-3643 token for this asset (one token per asset, Q8=A)
 6. Mint up to S to a *verified* provider/treasury wallet
DONE when: the lot is LIVE and tokens exist, backed by reserve ≥ supply.
```
Demo success criterion: a non-author runs steps 1–6 **unaided**.

## B. May this transfer happen? (the gate, every transfer/mint)
```
transfer(from, to, amt):
 1. paused?                      → yes: REVERT (TokenPaused)
 2. from frozen? (mint: skip)    → yes: REVERT (WalletFrozen)
 3. amt ≤ free (unfrozen) balance of from?  → no: REVERT (InsufficientUnfrozen)
 4. isVerified(to)?              → no: REVERT (ReceiverNotVerified)
 5. compliance.canTransfer(from,to,amt)?     (includes AssetLiveModule)
       └─ asset LIVE? + any extra module OK? → no: REVERT (ComplianceFail)
 all pass → move tokens, update frozen accounting, emit Transfer
```
This is the algorithm behind the 6 acceptance tests. The "bypass test" (T6.3) is just: call this directly on-chain with an unverified `to` and confirm step 4 reverts.

## C. Is a wallet verified? (identity resolution)
```
isVerified(w):
 1. id ← storage.storedIdentity(w);  if none → NOT verified
 2. T ← ClaimTopicsRegistry.getClaimTopics();  if T empty → CONFIG ERROR (never ship)
 3. for each topic t in T:
        issuers ← TrustedIssuersRegistry.issuersFor(t)
        found ← false
        for each claim c on id with c.topic == t:
            if c.issuer ∈ issuers AND not revoked AND signature valid:
                found ← true; break
        if not found → NOT verified   (return early)
 4. return verified
```

## D. Operator incident response (freeze / pause)
```
Signal: compromised wallet w
   → agent.setAddressFrozen(w, true)     (w can't send; others unaffected)
   → optionally freezePartialTokens(w, amt) to freeze only part

Signal: systemic incident (bug, exploit, legal halt)
   → agent.pause()                       (ALL transfers blocked)
   → investigate → agent.unpause() when safe

Signal: stale valuation / reserve shortfall on an asset
   → move asset LIVE → FROZEN            (minting halts; see §3 corollary in the maths note)
   → obtain fresh attestation → admit → FROZEN → LIVE
```

## E. Which contract answers which question? (routing cheat-sheet)
| Question | Answered by |
| -------- | ----------- |
| "May this wallet hold the token?" | IdentityRegistry.`isVerified` |
| "Which topics are required?" | ClaimTopicsRegistry |
| "Who may sign topic t?" | TrustedIssuersRegistry |
| "Does this investor satisfy topic t?" | their ONCHAINID claims (ERC-735) |
| "Is this specific movement allowed?" | ModularCompliance.`canTransfer` |
| "Does the asset permit a token at all?" | AssetRegistry state == LIVE (via AssetLiveModule) |
| "Is the reserve enough?" | AssetRegistry admission predicate, clause 3 |

---

## How to use this with the agent loop
Each flow above maps to tasks in [[M3 Task Board and Todo]]: A→T4+T6, B→T3+T2, C→T1, D→T3.2/T4, E is the wiring (T5). The **Researcher** uses these flows as the acceptance criteria it checks before checkmarking a task.

Up: [[Module 3 - Registry & Compliance]] · Related: [[Mathematics - Admission Predicate and Invariants]], [[Open Questions for Fahad]], [[Agents - Workflow]]
