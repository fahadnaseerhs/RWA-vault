# ADR 0022 — The platform holds no money: the fiat rail is an on-ramp integration seam

- **Status:** Accepted (2026-10-28, Q21)
- **Date:** 2026-10-27
- **Deciders:** Fahad Naseer

## Context

M8 was scoped as a mock settlement rail: PKR in, test-net USDC out, with a double-entry
ledger. That framing quietly assumed the platform sits in the middle of the money flow,
holding a PKR float and issuing USDC against it.

Two things make that the wrong assumption.

The first is the custody position the project is building toward. If investors hold their own
wallets and their own USDC, there is no reason for platform-controlled money to exist at any
point, and introducing it would make the fiat leg custodial while the token leg is not.

The second is regulatory, and it changed recently. Pakistan's **Virtual Assets Act, 2026**
took effect on **5 March 2026**, establishing **PVARA** as federal regulator, with eleven
licensable activity categories including exchange services and an application deadline of
5 September 2026 for existing firms. The **State Bank of Pakistan lifted its prohibition on
banks serving virtual-asset firms in April 2026**, while continuing to bar banks from holding
or trading virtual assets themselves. A real rupee-to-USDC path is therefore legally
conceivable in a way it was not before — but **operating that conversion is a licensable
activity**, which an FYP cannot hold a licence for. (These are secondary sources; the PVARA
regulations and State Bank circulars should be read directly before any of it is asserted in
the thesis.)

Industry practice resolves both at once. Non-custodial applications do not build fiat rails;
they embed a licensed third-party on-ramp that delivers crypto **directly to the user's own
wallet**, with the provider acting as **Merchant of Record**, so the integrating application
needs no money-transmitter licence because fiat never touches its balance sheet. MoonPay is
described as operating this way and Ramp Network as non-custodial; Transak positions itself as
embedded infrastructure that does not compete with its partners, though sources disagree on
whether its flow is custodial, so that one needs verifying directly.

## Decision

The platform never holds money — neither rupees nor USDC pass through an account we control.
Wallets and licensed providers hold the funds, and we integrate them.

`IFiatRail` is accordingly reframed as an **on-ramp integration seam**: the interface across
which a licensed provider is called and reports back, not the interface of a rail we operate.
For the FYP the provider behind that seam is **mocked**, so the MS2 gate still has a settlement
event to anchor a Merkle proof against.

How far the live money path eventually goes is **deferred to Phase 2**. The gold-purchase leg
requires physical metal and may stay out of scope entirely; token transfer, and
lending/borrowing against USDC or non-gold assets, are the parts that could plausibly run for
real. The seam is identical either way, which is why the question can wait.

## Consequences

**Good.** The non-custodial property now covers the money leg, not just the token leg, so the
custody description holds end to end. The project stays clear of an activity it cannot be
licensed for, and the architecture matches what licensed products actually do, which is a
stronger thesis position than a bespoke rail. Swapping the mock provider for a real one later
is an integration change behind an unchanged interface.

**Costly.** The double-entry ledger originally scoped for M8 loses its reason to exist in its
first form: there is no float to reconcile if we hold nothing. What remains is reconciliation
between the provider's reported settlements and our own record of them — still worth building,
and still what Experiment D injures, but a narrower artefact than planned.

**Harder.** MS2's gate reads "PKR 5,000 deposit → Merkle proof verifies offline." Under this
decision the rupee leg belongs to the provider, so the gate's wording has to say whether it
means our record of the provider's settlement or the provider's own receipt. Leaving that
ambiguous would make the milestone unfalsifiable. Keeping the mocked provider is what lets the
gate stay meaningful.

**Dependent on another decision.** This is only coherent if the operator also never holds
investor _tokens_. If that question is answered the other way, the platform becomes custodial
at the token layer and this decision buys much less than it appears to.

## Alternatives considered

**Model an operator-held PKR float (the original M8 shape).** Rejected: it makes the platform
a fiat custodian in the model, which contradicts the custody position and describes an
arrangement that would require a licence to run for real.

**Model a licensed third-party rail that we mirror in our own ledger.** Rejected as the primary
framing, though it is close to this decision and was the earlier recommendation. The
difference is where the user's funds land: mirroring still implies we take rupees and issue
USDC, whereas the on-ramp seam has the provider deliver straight to the user's wallet and
never routes value through us.

**Drop fiat entirely and assume investors arrive holding USDC.** Rejected: it is the smallest
build, but MS2's deposit gate stops meaning what it says, and the thesis loses the part of the
story that connects a Pakistani retail investor to the system at all.
