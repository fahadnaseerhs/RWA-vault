# ADR 0023 — Redemption is cash-settled; physical delivery is specified but not built

- **Status:** Accepted (2026-10-28, Q21)
- **Date:** 2026-10-27
- **Deciders:** Fahad Naseer

## Context

Whether a holder can exchange tokens for metal is what separates a gold _claim_ from a gold
_price tracker_, and it is among the first questions a finance examiner asks. It also decides
whether `burn` is a demonstrated path or only a unit test.

The two established tokenised-gold products both offer physical redemption, under heavy
constraints. PAXG is reported to redeem for LBMA-accredited Good Delivery bars, with
unallocated Loco London gold for institutional customers and a cash option at the prevailing
gold price. XAUT is reported to redeem physically only in increments of 430 tokens — a full
bar — only for KYC-verified customers who bought directly, and only with delivery inside
Switzerland. (Both from secondary comparison sources, which disagree on minimums; the issuers'
own documentation should be read before either figure is cited in the thesis.)

So physical redemption is not unusual for gold — it is gated by the fact that bullion exists
in standard bar sizes and cannot be divided on demand.

Two constraints then shape what is feasible here. A redemption threshold cannot be expressed
as a small cash amount: at the gold price implied by roughly PKR 400,000 per tola — Fahad
Naseer's undated working figure of 2026-10-27, not a sourced quote; see ADR 0020's provenance
note — one US dollar of gold is about 8 mg, which is neither assayable nor deliverable. That
conclusion is robust to the price: a dollar buys single-digit milligrams of gold across any
level the metal has traded at in recent years, so the threshold argument does not rest on the
figure. Any threshold has to
be a physically deliverable unit — in Pakistan, one tola (11.664 g) or a 10 g bar. And under
the project's own decisions the holder's claim attaches to an _identified lot_, so delivering
part of a registered 1 kg bar would break that allocation unless small bars and coins are
stocked specifically for redemption.

## Decision

Redemption is **cash-settled**. A holder exits by selling, or by redeeming tokens for value —
PKR or USDC — at the prevailing gold price, which burns the tokens and leaves the metal in the
vault undisturbed.

Physical delivery is **specified but not implemented**: an `IRedemption` interface records what
a physical request would look like — a deliverable-unit threshold, a custodian acknowledgement,
burn-on-release — and nothing satisfies it during the FYP. The thesis describes the token as a
cash-settled claim on an attested reserve, and says so plainly rather than implying delivery is
available.

## Consequences

**Good.** It removes the hardest operational problem in the project — splitting bars, assay,
insured transport, in-person identity checks — without removing the answer to the examiner's
question, because the interface shows the design was considered rather than overlooked. It also
keeps the allocation model intact: with no physical delivery, nothing ever needs to be taken out
of a registered lot, so fractional title to an identified bar survives untouched.

**Costly.** The token's link to spot price now rests on the issuer honouring cash redemption and
on secondary-market arbitrage, not on the threat of physical withdrawal. Physical redeemability
is the strongest peg mechanism there is, and declining it means the peg argument in the thesis
has to be made on weaker grounds and stated as such.

**Harder.** Cash settlement needs a source of cash. Under ADR 0022 the platform holds no money,
so a cash redemption is either routed through the same licensed provider as the on-ramp, or
settled in USDC from a buffer. That buffer's funding is unspecified here and belongs to M8's
research, which should treat it as an open item rather than an assumption.

**A legal subtlety worth recording.** If holders own fractional title to an identified bar, the
issuer cannot sell that bar to fund a cash redemption without the co-owners' consent. Cash
redemption therefore implies either a buffer, a market maker, or whole-lot disposal with
consent — a structure question, not a contract question, and one the claim-structure note must
address.

## Alternatives considered

**Physical redemption above a deliverable threshold, request-only and modelled.** The earlier
recommendation, and rejected only on scope. It would be 3–4 days: a request flow, a custodian
acknowledgement envelope, burn-on-release, plus an off-chain leg nobody performs during the FYP.
It remains the natural Phase 2 extension, and the `IRedemption` interface exists so that it is
an implementation rather than a redesign.

**Full physical redemption, executed in the demo.** Rejected: it needs a real custodian, real
metal, insured logistics and a licence, none of which an FYP has.

**A redemption threshold denominated in dollars (for example $1 or $0.50).** Rejected on the
arithmetic above — such a threshold corresponds to milligrams of gold, below any deliverable or
assayable quantity, and the handling cost would exceed the value redeemed by orders of
magnitude.
