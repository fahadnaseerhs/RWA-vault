# ADR 0020 — One token is one gram of gold

- **Status:** Proposed
- **Date:** 2026-10-27
- **Deciders:** Fahad Naseer
- **Amended:** 2026-10-27 — weight basis made explicit; the "1 kg lot mints 1,000 × 10¹⁸"
  example was wrong and is corrected. Amended in place rather than superseded because this
  record is still `Proposed`; see the Amendment section at the end for what changed and why.

## Context

The on-chain unit of account fixes the mint arithmetic in M3, the share arithmetic in M4,
the price denomination M5 must publish, and every numeric fixture in all three. It is
cheap to choose now and expensive to change once tests exist.

Three candidates were considered: one token per gram, per milligram, or per tola
(11.664 g), the unit gold is actually quoted and sold in across Pakistan.

The tola option was attractive for local relevance and was rejected on a concrete ground.
At roughly PKR 400,000 per tola, a one-token-per-tola denomination would make the smallest
holdable amount cost about four lakh rupees, against a target minimum investment of about
PKR 1,000–2,000.

That objection does not transfer to grams, and the reason matters enough to record: with
18 decimals the token unit is a **denomination, not a minimum purchase**. At the gold price
implied above — about PKR 34,300 per gram — a PKR 1,000 purchase is 0.029 tokens, which is
represented exactly. A minimum investment, if the product wants one, is a check in the
deposit path, not a property of the unit.

## Decision

One token represents **one gram of fine gold**, with 18 decimals.

**The weight basis is fine (assay) grams, and it is the same on all three sides of the
arithmetic:**

| Quantity                                    | Basis               |
| ------------------------------------------- | ------------------- |
| `intendedSupply` (tokens minted for a lot)  | fine grams          |
| Attested reserve (what the custodian signs) | fine grams          |
| `unitValue` (the valuation)                 | price per fine gram |

So a 1 kg kilobar of 999.9 fineness holds **999.9 g of fine gold and mints 999.9 × 10¹⁸ base
units — not 1,000 × 10¹⁸.** Gross bar weight never appears in supply, reserve or price.

M5 publishes gold prices per fine gram, which is already how LBMA benchmarks are quoted.
Tola and milligram are **display units only**, formatted in the M10 client; neither appears in
contract storage or in an interface signature.

## Consequences

**Good.** The gram is the unit LBMA pricing and the wider market use, so oracle sources need
no conversion before aggregation, and a reader comparing our figures to a market quote does
no arithmetic. Integer gram quantities keep M4's rounding-direction rules and its σ = 10⁶
virtual offset working on clean numbers. Fixtures stay readable in the thesis.

**Costly.** Small purchases display as fractional token amounts — a PKR 1,000 holding reads
as `0.029` rather than a whole number, which is worse UX than a milligram denomination would
give. We accept this because it is a formatting concern in one place, and M10 needs
locale-aware formatting anyway in order to show tola to Pakistani users.

**Harder.** Two unit systems now coexist by design: grams on-chain, tola in the interface.
Every place that formats a quantity has to convert, and a conversion error will be a display
bug rather than an accounting one — annoying, but not a loss of funds. The constant belongs
in one shared module, not inline at each call site.

**Carried into other modules.** M5's price feed, M4's share conversions and M8's settlement
amounts all inherit the gram. Any later asset class with a different natural unit — a T-bill,
a REIT share — gets its own token under ADR 0016, so this decision does not constrain them.

## Alternatives considered

**One token per milligram.** Rejected. It reads better for small holdings, but every fixture
in M3, M4 and M5 grows by a factor of 1,000 for no behavioural gain, and it moves the
on-chain unit away from the one the price sources quote.

**One token per tola.** Rejected on the arithmetic above: the smallest holdable unit would
cost roughly 400,000 rupees against a target minimum of 1,000, and a non-integer gram
conversion (11.664) would propagate into M4's rounding rules, where it interacts badly with
the inflation-attack hardening that depends on predictable rounding direction. Tola is
retained where it belongs, in the interface.

**Gross weight as the minting basis.** Rejected during the amendment below. It would let a
1 kg bar mint a round 1,000 × 10¹⁸ and keep the tidy example, at the cost of every token
over-claiming fine gold by 0.01%. A small number, but a _deliberate_ over-claim, and
"backed" is the single property the project rests on.

## Amendment — 2026-10-27

**What was wrong.** The Decision section originally read "one token represents one gram of
fine gold … a 1 kg lot _therefore_ mints 1,000 × 10¹⁸ base units." Those two clauses agree
only for chemically pure gold. A real 1 kg kilobar is 999.9 fine: 1,000 g gross, 999.9 g of
fine gold. The word "therefore" silently converted a fine-gold claim into a gross-weight
count.

**Why it mattered more than a rounding slip.** The invariant `attestedSupply ≤ reserve` is
only meaningful if both sides measure the same _substance_. Left as written, the ADR admitted
two implementations, each citing it:

- reserve attested in fine grams, supply minted on gross — then `999.9e18 ≥ 1000e18` is false
  and admission **rejects an honest bar** with `ReserveTooLow`. The project's own fixture lot
  would have failed at the MS1 demo, which is the worse of the two failures: a provider with a
  genuine bar turned away in front of the audience.
- supply minted on gross and reserve counted on gross — then the inequality passes, and every
  token over-claims fine gold by 0.01% by construction.

**The fix.** Fine grams on all three sides, stated in the table above, and the worked example
corrected to 999.9 × 10¹⁸ for a 999.9-fine kilobar. `unitValue` was added to that table during
this amendment: it carried the same ambiguity and nobody had noticed, because a price "per
gram" reads unambiguous until you ask which gram.

**Found by** the M3 Debugger's unit sweep, ruled for M3 by the Researcher session, and amended
here because the record is this session's. The decision in substance — one token, one gram — is
unchanged; only its basis and its example are.

**Follow-on, not done here.** Fineness should be a **schema field**, not prose in the lot
description, so the onboarding script can derive `intendedSupply = grossWeight × fineness` and
reject a mismatch. As free text, nothing can check a number that supply depends on.

## Provenance of the figures in this record

Stated once here because this record is cited from the thesis, and an undated price reads as a
market claim.

**PKR 400,000 per tola** is Fahad Naseer's working figure, given in discussion on 2026-10-27.
It is **not a sourced quote** and carries no date of its own. Every other number in this record
is derived from it: PKR 34,300 per gram is 400,000 ÷ 11.664, and the 0.029-token purchase is
PKR 1,000 ÷ 34,300.

As a sanity check rather than a source, it is consistent with contemporaneous reporting — the
LBMA afternoon fix was reported at about USD 4,124.55/oz on 8 October 2026 and a spot bid at
about USD 4,123.60/oz on 20 October 2026, which is roughly USD 133 per fine gram and implies an
exchange rate near PKR 259/USD. Those are secondary sources that disagree by tens of dollars,
so they establish the order of magnitude and nothing finer.

**Nothing in this decision depends on the price level.** The argument against tola is that one
token would cost a large multiple of the target minimum investment, which holds across any
plausible gold price; the argument for grams is that 18 decimals make the unit a denomination
rather than a minimum. If the price moves by a factor of two, both arguments are unchanged.

Any figure quoted as current in the thesis or in demo material must carry its date and source,
or be marked a placeholder — the convention the M3 fixtures already follow, where the synthetic
`unitValue` declares itself in its own `source` string.
