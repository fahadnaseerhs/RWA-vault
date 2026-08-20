# ADR 0011 — ETHFALCON: pin the commit, and use the NIST-compliant verifier

- **Status:** Proposed
- **Date:** 2026-08-20
- **Deciders:** Fahad Naseer, Hassan Attique, Fawaz Asif

## Context

§5.7 requires us to vendor or pin the reviewed ETHFALCON verifier at an immutable
version or commit, record its licence and upstream source, define exactly how Falcon
public keys, signatures and message inputs are encoded between M1 and Solidity, and
publish the deployment and per-verification gas figures that answer RQ3.

ETHFALCON (`ZKNoxHQ/ETHFALCON`, MIT) is the only credible Solidity Falcon verifier.
It ships three contracts, and the difference between them is the whole decision:

| Contract          | Approx. gas | What it verifies                                        |
| ----------------- | ----------- | ------------------------------------------------------- |
| `ZKNOX_falcon`    | 3.9M        | NIST-compliant Falcon, tested against official KATs     |
| `ZKNOX_ethfalcon` | 1.5M        | An EVM-friendly variant that replaces SHAKE with Keccak |
| `ZKNOX_epervier`  | 1.6M        | A variant with public-key recovery                      |

The cheap numbers that appear in ETHFALCON's own write-ups and in press coverage —
1.5M gas, a twelve-fold improvement over 24M — belong to `ZKNOX_ethfalcon`, not to
the NIST-compliant contract. That variant substitutes Keccak for SHAKE inside the
hash-to-point step, which makes it a different signature scheme: signatures produced
by a standards-conformant Falcon-512 signer do not verify under it, and signatures
that do verify under it are not Falcon-512 signatures. Adopting it would mean the
investor device signs something PQClean cannot produce and no NIST vector set covers,
in exchange for gas on a path the design says is exceptional.

The repository also carries an explicit warning from its authors that the work is
experimental and unaudited and must not be used in production.

The proposal's break-even derivation assumed `Gfal ≈ 1.5×10⁶`. If we select the
NIST-compliant contract, that constant is wrong by a factor of about 2.6, and the
consequences need working through rather than noting.

## Decision

**Pin `ZKNoxHQ/ETHFALCON` at commit `7d5ecd41ce1e0346afc835d20a9014e5a076843e`**
(10 June 2026, "Falcon verif solidity"), MIT licence. The contracts and their
dependencies are vendored into `contracts/lib/ethfalcon/` with a `PROVENANCE.md`
recording the upstream URL, the commit SHA, the licence text, and the SHA-256 of
every vendored file. A pinned commit rather than a submodule tracking a branch: the
repository is under active development and has no release tags, so a branch pointer
would let the dispute path change under us between a gas measurement and a thesis
that cites it.

**Use `ZKNOX_falcon`, the NIST-compliant verifier, and accept approximately 3.9M
gas.** The dispute path must adjudicate the same signature the investor's device
produced under ADR 0003 and the same signature the ADR 0009 KATs cover. A verifier
that requires a different hash function inside the scheme cannot do that, however
cheap it is.

**Encoding between M1 and Solidity.** M1 owns the adapter and it is a pure,
separately tested function, not glue inside a test:
`falcon_to_evm(pk: [u8; 897], sig: [u8; 666]) -> (salt, s2_coefficients, pk_ntt)`,
producing the compacted polynomial representation the verifier expects — sixteen
coefficients packed per `uint256` word, with the public key supplied in the NTT
domain. M1's canonical forms remain the raw 897-byte key and 666-byte signature of
ADR 0006; the EVM form is a projection of them, computed on demand and never stored
as the canonical value. The exact field layout is transcribed from the pinned
commit's interface and fixed in the adapter's doc comment, so a future upstream
change is a compile error rather than a silent verification failure.

**Testing.** The Foundry suite draws from Sources B and E of ADR 0009 — the Round 3
KATs and the project golden vectors — so the on-chain verifier and the off-chain
signer are checked against the same fixtures rather than against each other.
Positive, negative (bit-flipped signature, bit-flipped message, wrong key), malformed
(wrong-length inputs, out-of-range coefficients) and boundary cases are all required,
each asserting the specific revert or the specific `false`.

**Gas measurement** is taken under the pinned settings of ADR 0008 — `solc` 0.8.26,
optimizer on at 200 runs, `evm_version` explicitly set and verified against Arbitrum
Sepolia — and reports deployment gas and per-verification gas separately, with a
`forge snapshot` regression threshold in CI.

**The policy conclusion is fixed in advance: the verifier is dispute-only.** No
routine path may call it. The RQ3 report states this and states the measured numbers
that justify it.

### Consequence for the break-even argument

With `Gfal = 3.9×10⁶`, the proposal's own equations move as follows. The break-even
against the ECDSA baseline is unchanged, because at `δ = 0` the marginal cost
`g(n) = Gₐ/n` does not contain `Gfal` at all: anchoring still beats `Gec = 3,000`
from `n > 43,000/3,000 ≈ 14.3` events per epoch. The direct-verification comparison
gets _stronger_, since `Cost_direct(n) = n·Gfal` is now 2.6× worse, which sharpens
the premise of Model 8 rather than weakening it.

What does tighten is the tolerable dispute rate. At `n = 100` events per epoch,
anchoring remains cheaper than the baseline only while

`Gₐ/n + δ(G_p + Gfal) < Gec`

With `G_p = 22,000`: at `Gfal = 1.5×10⁶` this permits `δ < 1.7×10⁻³`, roughly one
disputed event in 592; at `Gfal = 3.9×10⁶` it permits `δ < 6.6×10⁻⁴`, roughly one in
1,526. The design's tolerance for disputes falls by about 2.6×, and it is still two
to three orders of magnitude above any plausible dispute rate for a sandbox
deployment. The RQ3 report presents both constants and this sensitivity, so the
argument stands on the measured number rather than the assumed one.

## Consequences

**Good.** The dispute path verifies exactly the signature the device produced. The
chain of custody from Falcon KAT to Rust core to WASM signer to Solidity verifier is
one signature format the whole way, and one set of fixtures tests all of it.

**Good.** Pinning a commit with recorded checksums makes the gas figure citable. A
number measured against a moving branch is not a result.

**Good.** The break-even analysis is now grounded in a measured constant, and the
sensitivity is published rather than buried. Discovering that the headline 1.5M
figure belongs to a different scheme is itself a finding worth reporting — it is the
kind of thing a reader would otherwise assume we had glossed.

**Costly.** 3.9M gas is a large single transaction. On Arbitrum Sepolia this is
affordable for an exceptional path; on L1 it would be marginal. The report must state
the chain the measurement was taken on and must not present the figure as
chain-independent.

**Costly.** We give up a 2.6× gas saving that is genuinely available, in exchange for
standards conformance. The trade is recorded so it can be revisited if the dispute
path ever becomes non-exceptional — but if it does, the correct response is to
redesign the adjudication path, not to change the signature scheme the investor's
device uses.

**Costly.** We depend on unaudited, self-described experimental contracts. This is
consistent with the project's sandbox posture — testnet, mock settlement, no real
funds — and the RQ3 report must repeat the upstream warning rather than omit it. A
production deployment would require an audited verifier, and no such verifier exists
today.

**Costly.** The compacted-polynomial adapter is fiddly code between two
representations, and an error in it produces a verifier that rejects valid
signatures — or, far worse, one that accepts something it should not. It is
separately unit-tested against the KAT fixtures in both Rust and Solidity, and it is
reviewed as cryptographic code.

**Watch item.** EIP-8052 proposes a Falcon precompile and EIP-7885 an NTT precompile;
with NTT precompiles ETHFALCON reports verification under 480K gas. Neither is
available on Arbitrum Sepolia today. If either lands during the project, the gas
report is re-run and the change noted; it does not alter this decision, only its
cost.

## Alternatives considered

**`ZKNOX_ethfalcon` at 1.5M gas.** Rejected: it replaces SHAKE with Keccak inside the
scheme, so it does not verify NIST Falcon-512. Adopting it would force the investor
device to sign a non-standard variant that PQClean cannot produce and that no NIST
vector set covers, breaking the conformance chain of ADR 0009 for the sake of gas on
a path the architecture deliberately makes rare. Cheap verification of the wrong
thing is not verification.

**`ZKNOX_epervier` at 1.6M gas with public-key recovery.** Rejected for the same
reason plus one more: recovery would let a caller omit the public key from calldata,
which is a saving the anchoring design does not need, since M2's key registry already
holds the key and the envelope already names the signer.

**Write our own Solidity Falcon verifier.** Rejected: it is a research project in its
own right, ETHFALCON took substantial specialist effort to reach 3.9M gas, and the
proposal's position is to consume reviewed cryptographic implementations rather than
hand-roll them. Hand-rolled NTT code in Solidity is exactly the class of thing that
position exists to forbid.

**Track the upstream default branch via a git submodule.** Rejected: the repository
has no release tags and is actively developed, so the verifier could change between
the gas measurement and the write-up that cites it. An immutable commit is what §5.7
asks for.

**Skip the on-chain verifier entirely and make disputes an off-chain process.**
Rejected: it deletes RQ3, and it removes the property that makes the anchoring
argument credible — that a user can, in the exceptional case, obtain adjudication
that does not depend on the platform's own verification. The whole point of measuring
the cost is to establish that the escape hatch exists and is affordable when used
rarely.
