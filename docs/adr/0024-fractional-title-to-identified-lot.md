# ADR 0024 — A token is fractional title to an identified lot

- **Status:** Proposed
- **Date:** 2026-10-27
- **Deciders:** Fahad Naseer

## Context

What a holder legally owns decides whether the system can describe itself as asset-backed, and
it governs what proof-of-reserve is evidence _of_. It is paper rather than code, but it is not
free-standing: the architecture has already made commitments that constrain it.

ADR 0016 put **one ERC-3643 token per asset**, and M3's AssetRegistry registers each lot with
its serial number, weight and purity. One token contract therefore corresponds to one
identified bar. ADR 0023 then made redemption **cash-settled**, so no metal is ever removed
from a registered lot.

Those two decisions together remove the objection that previously made this question hard. The
difficulty with per-bar title was always physical redemption: handing one tola out of a
registered 1 kg bar damages an allocation that other holders co-own, which would have forced
either a stock of small bars and coins or a pooled model. With cash settlement, nothing leaves
the bar.

Three structures were considered: a beneficial interest in a pooled holding, fractional title
to an identified lot, and a gold-referenced debt claim against the issuer.

## Decision

A token represents **fractional title to an identified lot** — a specific bar, recorded in the
AssetRegistry with its serial number, weight and purity, against which a post-quantum signed
reserve attestation is published.

This is recorded in a short claim-structure note in `docs/`, cited from the thesis, and
explicitly marked as a description of intended structure rather than legal advice.

## Consequences

**Good.** It is what the contracts already do, so nothing is reworked. It is also the only
structure in which the project's distinctive contribution means anything concrete: a holder can
name their bar's serial, read the attestation covering it, and check that
`attestedSupply ≤ reserveAmount` held for _that_ lot at every block. A pooled claim would make
proof-of-reserve a statement about an aggregate the holder cannot locate.

**Costly.** Co-ownership of movable property by many parties is the part of this with the least
settled footing in Pakistani law, and the project has no counsel. The claim-structure note has
to be honest about that rather than asserting a structure it cannot substantiate — one
paragraph, clearly labelled.

**Harder, and this is the live one.** Because holders own title to a specific bar, the issuer
cannot sell that bar to fund a cash redemption without co-owner consent. Cash settlement under
ADR 0023 therefore requires a buffer, a market maker, or whole-lot disposal with consent. This
is a structure question, not a contract change, and it belongs in M8's research as an open item.

**Constrains future assets.** Per-lot title works for bullion because a bar is identifiable.
A T-bill or a REIT share may not map onto "an identified lot" at all, and under ADR 0016 each
gets its own token anyway, so a different claim structure per asset class is permitted. This
record governs gold.

## Alternatives considered

**Beneficial interest in a pooled holding (trust-style).** Rejected, though it is the legally
smoothest option and has direct precedent in the established tokenised-gold products, which
makes it the easiest to cite and the easiest to fund cash redemptions from. It was rejected
because a pooled claim wants one token spanning many bars, which would mean re-opening ADR 0016
and discarding the per-lot registry that gives the attestation design its point.

**A gold-referenced debt claim against the issuer.** Rejected: it is the simplest paper, but the
token stops being asset-backed in any meaningful sense, and proof-of-reserve becomes evidence
about the issuer's inventory rather than about the holder's property — which removes the reason
the project exists.
