# ADR 0021 — A stale reserve attestation freezes minting only

- **Status:** Proposed
- **Date:** 2026-10-27
- **Deciders:** Fahad Naseer

## Context

Clause 4 of the admission predicate rejects an attestation whose valuation is older than τ.
That covers _admission_. It says nothing about what the system does when an asset is already
LIVE and no fresh attestation arrives — the custodian has simply gone quiet.

M5 already sets a precedent for the adjacent case: a stale _price_ freezes new borrows and
new locks, but never blocks repay or withdraw. The open question was whether a stale
_reserve attestation_ should carry the same consequence, a lighter one, or a heavier one.

Three responses were on the table: freeze minting only; freeze minting and new borrows; or
freeze the asset outright. The third was rejected early — an automatic FROZEN transition
hands an off-chain party the power to halt every holder's transfers by failing to sign,
which is a denial-of-service switch handed to the custodian.

## Decision

A stale reserve attestation freezes **minting only**. Transfers, borrows, repayments and
withdrawals all continue.

The asymmetry with M5's price rule is deliberate, and the reasoning is recorded here because
it is the first thing a reader will challenge:

1. **Minting is the only action that increases the claim on the reserve.** Blocking it is the
   exact, minimal response to uncertainty about the reserve's size. Borrowing does not change
   the token-to-metal ratio.
2. **A reported shortfall is a different event, and is handled harder.** The case where an
   attestation reports _less_ reserve than the supply already minted is governed separately
   and blocks minting with an explicit under-reserve signal. "Stale" means nobody has spoken
   lately; "under-reserved" means we have been told it is short. The second is the stronger
   signal and receives the stronger response.
3. **Freezing borrows would let a silent custodian halt a core protocol function.** That is a
   liveness cost paid for someone else's inaction, and it is a centralisation vector the
   project otherwise works to remove.

## Consequences

**Good.** The response is proportionate and cannot be weaponised: a custodian who stops
signing cannot stop anyone trading, borrowing, repaying or exiting. It is also the simplest
to implement — one state flag and one gate on the mint path — with no coupling from the
registry into the lending module.

**Costly, and this is the real exposure.** During a prolonged attestation outage the protocol
continues to extend credit against backing that has not been reconfirmed. If the metal left
the vault during that window, the loss surfaces only when the next attestation arrives. We
accept this because minting — the action that would compound the problem — is already
blocked, and because the alternative pays a permanent liveness cost against an intermittent
risk.

**Mitigations, none of which eliminate it.** τ is short (24 h for gold under the companion
decision), so the window is bounded in the normal case. A reported shortfall is caught by the
under-reserve path. The operator's manual freeze remains available for a judgement call that
the contract should not make automatically.

**Obligation on the evaluation.** Experiment C must include a stale-reserve-then-borrow path,
so that this decision's residual risk is measured rather than asserted. A decision taken with
a named risk and no measurement of it is weaker than one with either.

**Documentation debt.** Because this diverges from M5's price rule, the divergence has to be
stated wherever the freshness model is described — the maths note, Experiment C's write-up and
the thesis's risk section — or a reader will read it as an inconsistency rather than a choice.

## Alternatives considered

**Freeze minting and new borrows,** matching M5's price-staleness rule. Rejected after
weighing it directly: it is the more conservative option and gives the system one uniform
principle, but it lets a custodian's silence suspend lending, and it conflates a known
shortfall with an absence of news. It remains the right fallback if the measured outage
behaviour in Experiment C turns out worse than expected, in which case this record should be
superseded.

**Automatic asset freeze.** Rejected: one bad or missing attestation — a typo, a stale feed, a
holiday — would trap every holder, with no human in the loop.
