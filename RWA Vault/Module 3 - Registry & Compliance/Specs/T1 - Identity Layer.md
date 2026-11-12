---
type: spec
id: M3-T1
module: M3
task: T1
status: spec-complete
agent_state: handoff-to-coder
author: researcher
written_on: 2026-11-11
adrs: [0012, 0015, 0016, 0025, 0028, 0029, 0030]
questions: [Q01, Q02, Q03, Q07, Q15, Q23, Q24, Q25]
tags: [rwa-vault, m3, spec, t1]
updated: 2026-11-11
---
# T1 — Identity Layer Specification

Rules the seven items the Coder needs beyond Q23–Q25. **Specification only — no code written.** The Coder plan and acceptance criteria are handed off in [[Thread - T1 Identity Layer]].

> ## One step needs the user's go-ahead before it runs
> **T1.1 adds a git submodule — a download from GitHub and a new dependency in the build.** That is the user's call, not mine and not the Coder's. Everything in §2 specifies *how* to do it and *what to check*; none of it authorises doing it. T1.3 onward can be built while that is pending.

---

## 0. What T1 is, in reality

The gold bar is attested. Tokens are about to exist. **T1 is the bouncer on the door.**

A wallet asks to receive tokens, and something has to answer *"is this person allowed to hold this?"* — in one on-chain call, on every mint and every transfer, forever. T1 builds the thing that answers, and it answers by checking four things:

| | In plain words | Contract |
| --- | --- | --- |
| 1 | Which identity does this wallet belong to? | `IdentityRegistryStorage` → `IdentityRegistry` |
| 2 | What must be proven to hold this token? | `ClaimTopicsRegistry` — one thing: **KYC**, topic `1` |
| 3 | Whose word do we take on that? | `TrustedIssuersRegistry` — one ECDSA project issuer |
| 4 | Does this identity actually hold that claim, unrevoked? | the investor's **ONCHAINID** |

It all reduces to **`isVerified(address)`**. True and the wallet may hold tokens; false and the mint reverts with `ReceiverNotVerified` — which is the sentence the man in the terminal reads when he skips our website. T1 is what makes the *permissioned* half of "permissioned token" real.

---

## 1. The shape of the risk

The task note lists six tidy subtasks. **Five are routine; T1.1 is the whole risk.** It vendors a foreign codebase into a pinned toolchain whose upgrade model contradicts ours, and the three failure modes below are not in the note. Build T1.3, T1.4 and T1.5's skeletons first if T1.1 stalls — they depend on the *interfaces*, which already exist, not on the vendored code.

---

## 2. T1.1 — vendoring `onchain-id` (Coder item 1) ⚠ SUPERSEDED BY §11

> **This section assumed a git submodule. Q26/Q23a (2026-11-12) chose copy-vendor instead, and §2.2's per-path solc
> profile was wrong twice over.** Read **§11** for the procedure that applies. §2 is kept because §2.1's fact-gathering
> order and §2.3's proxy check still hold, and because what it got wrong is worth seeing.

### 2.1 I am not naming a commit from memory

**Ruling: the Coder reports the candidate; I rule it.** I will not write a tag or commit hash into this spec from recollection — that is the "remembered number" failure that cost three ADR renumbers, and here it would pin our identity layer to a commit nobody verified.

**The procedure, in order:**

1. Identify Tokeny's `onchain-id` Solidity repository and **report the URL, the latest release tag, and that tag's commit hash** back to me before adding anything.
2. With it, report four facts, each quoted from the actual files: the **licence** (must be GPL-3.0-compatible with our headers), the **pragma** in `Identity.sol` and `ClaimIssuer.sol`, whether **`Identity` has a constructor** or only an initializer (§2.3), and whether its `IIdentity` is at a stable path.
3. I rule the pin. Then the user authorises the `git submodule add`.
4. **Pin a commit, never a branch.** A branch moves under us and ADR `0025` means no proxies, so a silently-changed identity implementation is a redeploy.
5. **Remapping name: `onchain-id/`**, in `contracts/remappings.txt`, matching the `forge-std/` and `@openzeppelin/contracts/` convention already there.
6. **Do not edit vendored files.** An edited submodule is a fork that silently stops tracking upstream, which defeats Q01=C's reason for vendoring. If an edit looks unavoidable, stop and ask.

### 2.2 Pragma reconciliation (Coder item 3)

`foundry.toml` pins `solc_version = "0.8.26"` exactly; our interfaces use `pragma solidity ^0.8.20`, which is satisfied. If upstream pins an **exact** pragma that is not `0.8.26`, it will not compile, and that is the likely case.

**Ruling, in preference order:**

1. **If upstream's pragma is a caret range** admitting 0.8.26 — nothing to do.
2. **If it pins exactly** — add a **per-path solc profile** for the vendored directory in `foundry.toml`. Two compiler versions in one project is ugly; a forked submodule is worse, because the fork's divergence is invisible.
3. **Bumping or lowering our own pin to match upstream — rejected.** Our pin is load-bearing: T0.6's interfaces, the acceptance spec and every M3 contract compile against it, and moving it to suit a vendored dependency inverts which codebase is in charge.
4. **Editing the vendored pragma — last resort, and it needs my ruling plus an ADR**, because it converts the submodule into a fork.

### 2.3 The proxy collision (Coder item 7)

ADR `0012` vendors a proxy-based stack; ADR `0025` says plain deploys, no proxies, no storage gaps. **T1.1 is where that lands** — ADR `0025`'s own Context paragraph predicted it.

**Ruling: our registries are constructor-wired, full stop.** Four contracts, all ours, all plain deployments with constructors validating their parameters, no initializers, no storage gaps.

For the **vendored** half: upstream `Identity` is expected to support direct deployment via a constructor taking an initial management key and a library flag. **Verify it, do not assume it** — that is fact 3 in §2.1. If `Identity` turns out to be initializer-only and unusable without a proxy, then ADRs `0012` and `0025` are in genuine conflict, and that is Fahad's decision, not the Coder's. Stop and route it.

---

## 3. Q23 = A — what gets deleted (Coder item 2)

I mapped this on disk rather than estimating, and **the blast radius is narrower than it looks.**

**Our identity interfaces** — `src/identity/interfaces/`: `IIdentity.sol`, `IClaimIssuer.sol`, `IERC734.sol`, `IERC735.sol`.

**Everything that imports them — three lines in three files:**

| File | Line | Imports |
| --- | --- | --- |
| `src/registry/interfaces/IIdentityRegistry.sol` | 7 | `IIdentity` |
| `src/registry/interfaces/IIdentityRegistryStorage.sol` | — | `IIdentity` |
| `src/registry/interfaces/ITrustedIssuersRegistry.sol` | — | `IClaimIssuer` |

**`IERC3643.sol` and `ERC3643Acceptance.t.sol` do NOT reference them.** Both only touch `IIdentityRegistry`; a `grep` for `IIdentity` matches them only because `IIdentityRegistry` contains that substring. Worth stating because it is the natural wrong assumption, and it means the token interface and the acceptance spec need no edit.

**Ruling: delete all four, repoint the three imports at the submodule.**

Delete all four rather than only `IIdentity`, even though only two are imported. Keeping `IERC734` and `IERC735` as orphans leaves two copies of the ERC-734/735 definitions in the tree, and the next reader cannot tell which is authoritative — which is how the two diverge. `IClaimIssuer` goes for the same reason it came: `ITrustedIssuersRegistry` types against it, so it must be upstream's or the same mismatch recurs one interface along.

**The T0.5 re-run must show:** `forge build` green, and the six acceptance guarantees still compile unchanged. Since the spec never names `IIdentity`, the expected result is **no change at all** — and the re-run exists to *prove* that rather than assume it. If it does change, something imported through `IIdentityRegistry` depended on our declaration, and I want to know.

> **"Re-run" here means recompile, not execute** (Q28, decided 2026-11-12). `ERC3643AcceptanceTest` is `abstract`, so Forge never collects it; the T1 Debugger gate confirmed this by execution (`forge test --match-contract ERC3643AcceptanceTest` → "No tests found"; the 115-test run holds seven suites, none of them this one). The guarantees begin executing at T3.6.

---

## 4. Q24 = A — where topic `1` lives, and fail-closed (Coder item 4)

**Ruling: seeded in the constructor, and the last topic cannot be removed.**

```solidity
uint256 public constant KYC_TOPIC = 1;   // ADR 0029 — permanent
constructor() { _topics.push(KYC_TOPIC); }           // never deployable empty
error TopicSetCannotBeEmpty();                        // removing the last topic reverts
```

Both halves are needed, and this is the most important paragraph in the spec.

**An empty topic set makes `isVerified` vacuously true** — "for every required topic there exists a valid claim" is trivially satisfied when there are no required topics. That is a **fail-open in the one function the entire module exists to make fail-closed**, and it is reachable by a registry that is merely *unseeded* rather than misconfigured. Nobody has to do anything wrong.

So: the constructor seeds it, so an empty registry cannot be deployed; and `removeClaimTopic` reverts `TopicSetCannotBeEmpty` when one topic remains, so it cannot be emptied afterwards. A convention would not do — this needs to be unreachable.

**Additionally, `isVerified` must return `false` if it ever sees an empty topic set**, belt to the braces. If both guards hold it is unreachable; if someone later removes one, the gate still fails closed. Defence in depth is usually a weak argument; here the downside is "every unverified wallet in the world can hold the token", so it earns its place.

---

## 5. Q25 = A — the test issuer and the address rule (Coder item 5)

**Ruling: a deterministic Foundry test key, and three distinct addresses.**

In T1.6, derive the issuer with `vm.addr(ISSUER_PK)` for a **fixed, committed** private key constant, and sign claims with `vm.sign(ISSUER_PK, digest)`. Deterministic, so a failure reproduces; committed, so it is obviously a test key and nobody mistakes it for a secret. **Never a key that exists outside the test file**, and never one generated at runtime — a test that signs with a fresh key each run cannot reproduce its own failures.

**The separate-address rule, binding from Q25 and D3:** the KYC issuer, the registry's `agent`, and the attestation submitter are **three distinct addresses**. T1.6 must assert they differ — one stolen key must not both admit an investor and move tokens. The reasoning is D3's, extended a third time, and it is cheap to assert and expensive to discover missing.

---

## 6. The owner/agent model (Coder item 6)

**Ruling: the minimal custom check, consistent with T0.6. Not `AgentRole`, not OpenZeppelin `AccessControl`.**

Same named errors as `IAssetRegistry`: `NotOwner(address caller)`, `NotAuthorisedAgent(address caller)`. The reason is the one that settled it for T0.6: OpenZeppelin would revert `OwnableUnauthorizedAccount` / `AccessControlUnauthorizedAccount`, and **neither name is in [[T6 - Provider Onboarding Console]] §3.4's translation table** — so the onboarding script would print a hex selector at an operator for the single most likely operational error. ADR `0015` fixes exactly two roles, and two roles do not need a role framework.

`owner` is the 2-of-3 multisig; `agent` is the Tier 1 service key (ADR `0015`). `setIdentityRegistryStorage`, `setClaimTopicsRegistry` and `setTrustedIssuersRegistry` are **owner-only** — they can repoint the entire gate, so they sit where ADR `0015` puts registry setters. `registerIdentity`, `deleteIdentity`, `updateIdentity` and `updateCountry` are **agent**.

---

## 7. `isVerified` — the algorithm, restated as the contract

From [[Mathematics - Admission Predicate and Invariants]] §1, and this is what T1.5 implements:

```
isVerified(w):
  1. id ← storage.storedIdentity(w);      none          → FALSE
  2. T  ← topicsRegistry.getClaimTopics(); T is empty    → FALSE   (§4, fail closed)
  3. for each topic t in T:
       issuers ← issuersRegistry.getTrustedIssuersForClaimTopic(t)
       satisfied ← false
       for each claim c on id with c.topic == t:
            if c.issuer ∈ issuers AND NOT revoked(c) AND signature valid:
                 satisfied ← true; break
       if NOT satisfied → FALSE          (return early)
  4. return TRUE
```

**The subtlety that breaks naive implementations** is in step 3's first line: issuers are fetched **per topic**, not globally. An issuer trusted for *some* topic is not thereby trusted for *this* one. A naive implementation calls `isTrustedIssuer(issuer)` and passes a claim from a genuinely-trusted issuer who was never authorised for KYC. §8 makes that a required test.

---

## 8. Acceptance criteria

- **AC-T1-1** `forge build` and `forge fmt --check` green with the submodule present; no vendored file edited.
- **AC-T1-2** The submodule is pinned to a **commit**, not a branch, and the pin is the one I ruled.
- **AC-T1-3** All four of our identity interfaces are deleted; the three imports point at the submodule; `IERC3643.sol` and `ERC3643Acceptance.t.sol` are **unchanged**.
- **AC-T1-4** The T0.5 acceptance spec **compiles** and its six guarantees are unchanged. Any change is reported, not absorbed. **Compiling, never running** (Q28, decided 2026-11-12): `ERC3643AcceptanceTest` is `abstract` by design, so Forge does not collect it and no amount of execution can satisfy this criterion before T3.6 supplies the concrete subclass. Verified at the T1 Debugger gate on exactly those terms — unchanged on disk, compiles clean. The seventh `test_` function, `test_RegistryVerificationMatchesHolders`, is a consistency assertion rather than a guarantee, which is why the count is six.
- **AC-T1-5** `ClaimTopicsRegistry` cannot be deployed with an empty topic set, and `removeClaimTopic` reverts `TopicSetCannotBeEmpty` when one remains. Both tested.
- **AC-T1-6** `isVerified` returns **false** on an empty topic set. Tested directly, by constructing that state in a mock if the guards make it otherwise unreachable.
- **AC-T1-7** A claim from an issuer trusted **for a different topic** does not verify. `test_ClaimFromIssuerTrustedForAnotherTopicDoesNotVerify`.
- **AC-T1-8** A **revoked** claim does not verify; a **wrong-issuer** claim does not verify; an unregistered wallet does not verify.
- **AC-T1-9** `updateIdentity` moves verification to the new identity in the same transaction — the old identity's claims stop counting.
- **AC-T1-10** `updateCountry` changes `investorCountry` and does **not** affect `isVerified` (Q02 = A: no country rule).
- **AC-T1-11** The KYC issuer, `agent` and submitter are three distinct addresses, asserted.
- **AC-T1-12** All four contracts are constructor-wired: no initializers, no storage gaps, no proxy. Grep at review.
- **AC-T1-13** Every revert is a named custom error; no bare `expectRevert`. Every `assertTrue`/`assertFalse` carries a message. No assertion is implied by another in the same test — tested against the refined rule in [[Working Conventions]], where sibling entailment does not count because the test's own constants move with the edit.

---

## 9. Risks

| Risk | Severity | Mitigation |
| --- | --- | --- |
| Upstream pins an exact pragma ≠ 0.8.26 | **High** | §2.2's order; never move our own pin |
| Upstream `Identity` is initializer-only, so unusable without a proxy | **High** | §2.3 — verify before vendoring; if true, ADRs `0012`/`0025` conflict and it is Fahad's call |
| `ClaimTopicsRegistry` deployed or emptied with no topics → silent fail-open | **High** | §4's two guards plus AC-T1-6 |
| A naive `isTrustedIssuer` check ignores the topic | **Medium** | §7's subtlety, AC-T1-7 |
| An edited submodule becomes an invisible fork | **Medium** | AC-T1-1; stop and ask instead |
| T0.5 silently depended on our `IIdentity` | **Low** | AC-T1-4 proves rather than assumes |

---

## 10. Still owed, not blocking

Full ADR records against the `0028`–`0030` stubs. The decisions are binding and recorded in the question notes; the stubs say the records are owed on their face.

Up: [[Thread - T1 Identity Layer]] · Related: [[T1 - Identity Layer]], [[T0.6 - IAssetRegistry Interface]], [[Mathematics - Admission Predicate and Invariants]]

---

## 11. T1.1 and T1.2 under Q23a — copy-vendor (supersedes §2)

### 11.1 Why the submodule was not merely costly but impossible

Two build facts, both verified on disk, and the second is the one that closed the argument.

1. **Upstream pins `pragma solidity 0.8.17` exactly** — `Identity.sol`, `ClaimIssuer.sol` and all four interface files at release 2.2.1, and the same on main. 2.2.2-beta3 is `^0.8.27`. **None admits 0.8.26.**
2. **`contracts/foundry.toml:28` sets `solc_version = "0.8.26"` inside `[profile.default]`, and there is no `auto_detect_solc`.** So the pin applies to the **whole project**, not per compilation unit. A `0.8.17` file therefore fails to build **even if nothing imports it.**

Fact 2 is what makes §2.2's "per-path solc profile" wrong twice: an import edge is one compilation unit *and* the project pin leaves no per-path resolution to configure. It also killed the keep-our-own-type option, because that option's safety net was an integration test registering a real upstream `Identity` — and that test needs upstream source compiled in-tree, which the pin forbids. The only remaining route there was committing upstream's **prebuilt bytecode**, and that is vendoring in a form nobody can read, review or recompile. *Credit: the custody session found fact 2; neither I nor the Coder had.*

### 11.2 The procedure

Model it on `scripts/vendor-pqclean.py` + `scripts/verify-vendor.py`, which already copy-vendor a foreign codebase with an upstream-anchored, re-runnable provenance check. This is that machinery pointed at a second dependency.

1. **Pin an immutable commit, not a tag.** Tags can move; a commit hash cannot. Record the hash, the repo URL and the release it corresponds to.
2. **Copy only what we use** — `Identity.sol`, `ClaimIssuer.sol`, and the interfaces they and our registries need. Not the test suite, not the proxy machinery, not the factory. A narrower copy is a narrower audit surface, and the proxy contracts are exactly what ADR `0025` says we do not deploy.
3. **Destination:** `contracts/src/vendor/onchain-id/`. Under `src/` because it must compile with everything else — that is the entire point of the exercise — and under `vendor/` so a reader can see at a glance which code is not ours.
4. **The pragma is ours now.** Rewrite each copied file's pragma to `^0.8.20`, matching our own files, and have the script do it **mechanically and record that it did.** A hand-edited pragma is indistinguishable from a hand-edited anything.
5. **Record a content digest per file**, taken from the upstream object, so `verify-vendor`-style checking can prove the copy still matches upstream modulo the recorded pragma rewrite.
6. **The provenance check runs in CI.** A copy nobody verifies is a fork pretending to be a dependency — and unlike a submodule there is no `git submodule status` to notice drift for us.
7. **Keep the GPL-3.0 headers** exactly as upstream wrote them, and record upstream's `LICENSE.md` alongside the copy. Licences align — `onchain-id` is GPL-3.0 and so are we — but provenance is a separate obligation from compatibility.

### 11.3 What the pragma rewrite does and does not buy

**It is not a behavioural change and must not become one.** Widening `0.8.17` → `^0.8.20` lets our compiler accept the file; it does not alter semantics. The evidence that the source is actually fine on a later compiler is that **upstream themselves moved to `^0.8.27` in 2.2.2-beta3** — so the code is known to work past 0.8.20 by its own authors.

**What it does not buy: a guarantee.** Compiling 0.8.17-era source at 0.8.26 is still a compiler change, and the only honest proof is that the tests pass. Hence AC-T1-15: an end-to-end test that registers a **real vendored `Identity`** and asserts `isVerified` goes true. Under Q23a that test finally compiles in-tree, which is the whole reason this option won.

### 11.4 Acceptance criteria for T1.1 / T1.2

- **AC-T1-19** `scripts/vendor-onchain-id.py` (or an extension of the existing vendor tooling) pins an **immutable commit**, copies only the needed files to `contracts/src/vendor/onchain-id/`, rewrites each pragma to `^0.8.20` mechanically, and records a per-file digest.
- **AC-T1-20** Re-running the script on a clean tree reproduces the vendored directory **byte for byte**. A provenance script that is not idempotent proves nothing.
- **AC-T1-21** A `verify-vendor`-style check fails when any vendored file is edited by hand, and it runs in CI.
- **AC-T1-22** `forge build` green with the vendored source in `src/`, under the **existing** `0.8.26` pin — `foundry.toml` is unchanged except for nothing at all. If the pin needs touching, stop and ask.
- **AC-T1-23** Upstream's `LICENSE.md` is recorded alongside the copy and the GPL-3.0 headers in copied files are untouched.
- **AC-T1-24** The proxy and factory contracts are **not** copied. Grep at review: nothing under `vendor/` references a proxy pattern.
- **AC-T1-25** `ClaimIssuer` adapter tests (T1.2) exercise `isClaimValid` against a claim signed by the deterministic test key from §5, proving the vendored issuer verifies an ECDSA claim we produced.

---

## 12. T1.4 — `TrustedIssuersRegistry`

**In plain words:** the list of people whose word we accept, and *on what*. Not "who do we trust" but **"who do we trust about what"** — which is the distinction the whole contract exists to encode.

**Interface on disk:** `addTrustedIssuer(IClaimIssuer, uint256[])`, `removeTrustedIssuer`, `updateIssuerClaimTopics`, `getTrustedIssuers`, `getTrustedIssuersForClaimTopic`, `isTrustedIssuer`, `getTrustedIssuerClaimTopics`, `hasClaimTopic`.

**The thing to get right.** Two lookups exist and they are not interchangeable:

- `isTrustedIssuer(addr)` — trusted for **anything**?
- `getTrustedIssuersForClaimTopic(topic)` / `hasClaimTopic(addr, topic)` — trusted for **this topic**?

`isVerified` must use the **second**. An issuer trusted for *some* topic is not trusted for *this* one, and an implementation that reaches for `isTrustedIssuer` because it reads more naturally will accept a claim from a genuinely-trusted issuer never authorised for KYC. That is AC-T1-7 and it is the most likely defect in all of T1.

**Storage shape.** An issuer to topics mapping, an issuer array for enumeration, and a topic to issuers index so `getTrustedIssuersForClaimTopic` does not scan every issuer. `isVerified` runs on **every transfer**, so an O(issuers x topics) scan there is the same griefing surface `MAX_CLAIM_TOPICS` was capped for. Cap issuers per topic too.

**Owner-only** on all three mutators: adding a trusted issuer is adding a KYC authority, as privileged as repointing a registry.

- **AC-T1-26** `addTrustedIssuer` with an empty topic array reverts with a named error. An issuer trusted for no topics is a row that can never be used and reads as if it grants something.
- **AC-T1-27** `addTrustedIssuer` with a no-code address reverts. An issuer must be a contract, and `extcodesize` is the check a cast cannot do.
- **AC-T1-28** `getTrustedIssuersForClaimTopic(t)` returns **only** issuers authorised for `t`, tested with an issuer trusted for topic 7 and not for 1.
- **AC-T1-29** A cap on issuers per topic, same griefing rationale, with a test at the bound.

---

## 13. T1.5 — `IdentityRegistryStorage` + `IdentityRegistry`

**In plain words:** the address book, and the clerk who reads it. Storage holds wallet to identity and country; the registry answers `isVerified` by walking from a wallet to its identity's claims.

**Why two contracts** (ADR `0016`): identity storage is **shared across tokens** while compliance is bound 1:1. One investor KYC'd once should hold every asset we ever tokenise without re-registering. `IdentityRegistryStorage` is deployed once and `bindIdentityRegistry` links each token's registry to it. That matters even with one token today, because the alternative silently makes per-asset re-KYC the design.

**`isVerified` — the four failure points, in the order they bite:**

1. No identity linked, return false. Cheapest check, so first.
2. **Empty topic set, return false.** T1.3's guards make it unreachable; assert it anyway (AC-T1-6). The cost of being wrong is every unverified wallet on earth holding the token.
3. Per topic, fetch issuers **for that topic** (section 12) and look for one valid, non-revoked claim.
4. Any topic unsatisfied, return false **early**.

**Access split** (ADR `0015`): `registerIdentity`, `deleteIdentity`, `updateIdentity`, `updateCountry`, `batchRegisterIdentity` are **agent**. The three registry setters are **owner** — each can repoint the entire gate.

**Three things the task note does not say:**

- **`batchRegisterIdentity` must be all-or-nothing.** A partial batch leaves an operator unable to tell which half landed, and recovery becomes a diff against intent.
- **`updateIdentity` must move verification in the same transaction** — the old identity's claims stop counting immediately (AC-T1-9). A reader might reasonably expect it to add rather than replace.
- **`deleteIdentity` must not silently succeed on an unregistered wallet.** A no-op delete tells an operator the wallet is now unregistered when it never was.

- **AC-T1-30** `batchRegisterIdentity` reverts entirely if any element fails. No partial state.
- **AC-T1-31** `deleteIdentity` on an unregistered wallet reverts with a named error.
- **AC-T1-32** `isVerified` returns false for a wallet with an identity but **no claims at all** — a different path from no identity, where a zero-length loop returns the wrong default.
- **AC-T1-33** A storage bound to two registries serves both. The ADR `0016` sharing property, tested rather than assumed.

---

## 14. T1.6 — the test matrix

The task note lists five cases. These are the ones it omits, each of which passes a plausible implementation:

| # | Case | Why it is the one that slips |
| - | --- | --- |
| 1 | Claim from an issuer trusted **for a different topic** | The issuer *is* trusted; only the topic is wrong, and `isTrustedIssuer` returns true (AC-T1-7) |
| 2 | **Empty topic set** | `isVerified` is vacuously true rather than false — a fail-open that looks like a pass (AC-T1-6) |
| 3 | Identity with **no claims at all** | A different path from "no identity"; a zero-length loop returns the wrong default (AC-T1-32) |
| 4 | `updateIdentity`, then verify | The old identity's claims must stop counting **immediately** (AC-T1-9) |
| 5 | `updateCountry` | Must change the country and **not** affect `isVerified` — Q02 = A has no country rule (AC-T1-10) |
| 6 | Issuer **removed** after a claim was issued | The claim is intact; the authority is gone. Must verify false |
| 7 | Topic **added** after a wallet was verified | The wallet silently stops being verified |

**Case 7 is the one I would not have thought to ask for.** Adding a required topic retroactively unverifies everyone who lacks it. That is correct behaviour, and it is also a live operational hazard: an owner adding a topic can freeze every holder's transfers without touching the token. It deserves a test **and** a sentence in `addClaimTopic`'s NatSpec, because an operator who does it by accident will not connect the two.

**The signing issuer** is the deterministic committed key from section 5: `vm.addr(ISSUER_PK)` and `vm.sign(ISSUER_PK, digest)`, never runtime-generated, because a test that signs with a fresh key each run cannot reproduce its own failures. Three distinct addresses asserted — issuer, `agent`, submitter (AC-T1-11).

- **AC-T1-34** Case 6: a claim from a since-removed issuer does not verify.
- **AC-T1-35** Case 7: adding a topic unverifies a previously-verified wallet, and the behaviour is documented as intended in `addClaimTopic`'s NatSpec.

---

## 15. Order, and what is actually blocked

| Subtask | State | Depends on |
| --- | --- | --- |
| **T1.3** `ClaimTopicsRegistry` | built; invariant + CI profile owed, then a gate | — |
| **T1.4** `TrustedIssuersRegistry` | ready now | our `IClaimIssuer`, still present until T1.1 lands |
| **T1.5** storage + registry | ready after T1.4 | `getTrustedIssuersForClaimTopic` |
| **T1.1** copy-vendor | ready — Q23a decided | the provenance script |
| **T1.2** `ClaimIssuer` adapter tests | after T1.1 | the vendored issuer |
| **T1.6** test matrix | after T1.4 and T1.5; cases 1-7 complete after T1.1 | all of the above |

**Nothing waits on a decision any more.** T1.4 and T1.5 can be written against the interfaces that exist today, because Q23a changed *where upstream source lives*, not the ABI they are typed against — and the three import lines get repointed when T1.1 lands, which is one line per file.

**Full AC range for T1: AC-T1-1 to AC-T1-35**, with AC-T1-5 corrected, AC-T1-17 corrected to three properties, and sections 2.1-2.3 superseded by section 11.

Up: [[Thread - T1 Identity Layer]] · Related: [[T1 - Identity Layer]], [[Q23 - Which IIdentity type do our registries use]], [[Mathematics - Admission Predicate and Invariants]]
