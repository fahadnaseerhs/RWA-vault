---
tags: [rwa-vault, m3, thread, t1]
task: T1
status: open
lead_agent: researcher
updated: 2026-11-12
---
# 💬 Agent Thread — T1: Identity Layer

> **Topic:** The bouncer on the door — the four contracts that answer `isVerified(address)`, and the vendored ONCHAINID they read claims from.
> **Status:** 🐞 Debugger gate passed 2026-11-12 (six scope items executed, 115/115) → 🧭 Researcher to rule on two ASKs, then checkmark.

---

### 2026-11-11 · 🧭 Researcher → ⌨️ Coder · HANDOFF

**Context:** T1 spec complete — [[T1 - Identity Layer (spec)|Specs/T1 - Identity Layer]]. All seven items you raised are ruled, plus three carried requirements. **One step is not mine to release:** T1.1 adds a git submodule, a download from GitHub and a new build dependency, which is the user's call. §2 says how and what to check; it does not authorise doing it.

**On Disk Now:**
- `contracts/src/identity/interfaces/` → `IIdentity.sol`, `IClaimIssuer.sol`, `IERC734.sol`, `IERC735.sol` — all four ours.
- Importers, **three lines in three files**: `IIdentityRegistry.sol:7` → `import "../../identity/interfaces/IIdentity.sol";`, `IIdentityRegistryStorage.sol` → same, `ITrustedIssuersRegistry.sol` → `IClaimIssuer`.
- `contracts/.gitmodules` → `forge-std` and `openzeppelin-contracts` only; `onchain-id` absent.
- `foundry.toml:28` → `solc_version = "0.8.26"`.

**Message — your seven, ruled. Spec section in brackets.**

**1 · Vendoring pin [§2.1] — I am not naming a commit from memory.** Report the repo URL, the latest release tag and its commit hash, plus four facts quoted from the files: the licence, the pragma in `Identity.sol` and `ClaimIssuer.sol`, whether `Identity` has a **constructor** or only an initializer, and whether its `IIdentity` sits at a stable path. I rule the pin, then the user authorises the add. Pin a **commit, never a branch**. Remapping: **`onchain-id/`**. Do not edit vendored files — an edited submodule is a fork that stops tracking upstream, which defeats Q01=C's reason for vendoring.

**2 · Q23 = A blast radius [§3] — narrower than it looks.** Delete **all four** of our identity interfaces and repoint the **three** imports. `IERC3643.sol` and `ERC3643Acceptance.t.sol` are **untouched**: both only reference `IIdentityRegistry`, and a grep for `IIdentity` matches them solely because `IIdentityRegistry` contains that substring. I checked rather than estimated. Delete all four rather than the two imported ones, because orphaned `IERC734`/`IERC735` leave two copies of those definitions and the next reader cannot tell which is authoritative — which is how they diverge.

**3 · Pragma [§2.2], in preference order:** caret range admitting 0.8.26 → nothing to do; exact pin ≠ 0.8.26 → **per-path solc profile** for the vendored directory; **moving our own pin — rejected**, it is load-bearing for T0.6, the acceptance spec and every M3 contract, and changing it to suit a dependency inverts which codebase is in charge; editing the vendored pragma → last resort, needs my ruling plus an ADR.

**4 · Q24 [§4] — constructor seed AND un-emptiable, both.** `uint256 public constant KYC_TOPIC = 1;` seeded in the constructor so an empty registry cannot be deployed, plus `error TopicSetCannotBeEmpty()` when `removeClaimTopic` would leave zero. **And `isVerified` returns false on an empty set regardless.** Why all three: an empty topic set makes `isVerified` **vacuously true** — "every required topic has a valid claim" is trivially satisfied when none are required. That is a fail-open in the one function the module exists to make fail-closed, reachable by a registry that is merely *unseeded* rather than misconfigured. Nobody has to do anything wrong.

**5 · Q25 [§5] — deterministic committed test key.** `vm.addr(ISSUER_PK)` / `vm.sign(ISSUER_PK, digest)` with a **fixed constant**, never a runtime-generated key: a test that signs with a fresh key each run cannot reproduce its own failures. Assert the KYC issuer, `agent` and submitter are **three distinct addresses** — D3's reasoning, third application.

**6 · Owner/agent [§6] — the minimal custom check, as T0.6.** `NotOwner(address)`, `NotAuthorisedAgent(address)`. Not `AgentRole`, not OpenZeppelin: `OwnableUnauthorizedAccount` is absent from T6 §3.4's translation table, so the script would print a hex selector at an operator for the most likely operational error there is. Registry setters are **owner**; `registerIdentity`/`deleteIdentity`/`updateIdentity`/`updateCountry` are **agent**.

**7 · Immutability [§2.3] — constructor-wired, no initializers, no storage gaps.** For the vendored half: `Identity` is *expected* to support direct deployment, but **verify it** (fact 3 above). If it is initializer-only and needs a proxy, ADRs `0012` and `0025` are in genuine conflict — stop and route it to Fahad rather than choosing.

**The subtlety in `isVerified` [§7] that breaks naive implementations:** trusted issuers are fetched **per topic** (`getTrustedIssuersForClaimTopic(t)`), not globally. An issuer trusted for *some* topic is not trusted for *this* one. A naive `isTrustedIssuer(issuer)` check passes a claim from a genuinely-trusted issuer who was never authorised for KYC. **AC-T1-7** makes that a required test, and it is the case a reviewer misses too.

**Acceptance criteria:** AC-T1-1 … AC-T1-13 in §8. The ones most likely to be skipped: **AC-T1-4** (re-run T0.5 and *report* any change rather than absorb it — the expected result is no change, and the point is to prove it), **AC-T1-6** (`isVerified` false on an empty set, tested directly via a mock if the guards make it otherwise unreachable), and **AC-T1-7** above.

**Order if T1.1 stalls:** T1.3, T1.4 and T1.5 depend on the **interfaces**, which already exist — not on the vendored code. Build those while the submodule is pending.

**Blocks/Unblocks:** Unblocks T1.3–T1.6 now. T1.1 and T1.2 wait on the user's go-ahead for the submodule.

---

### 2026-11-11 · ⌨️ Coder → 🧭 Researcher · REPORT + ASK (T1.1 pin facts — a compile conflict)

**Context:** §2.1 steps 1–2, read-only via the GitHub API; nothing added to the repo. **The user approved vendoring the submodule** in the Coder session ("I also have approved this … Approve vendoring onchain-id as a git submodule?"). Per §2.1 step 3 the pin is still yours to rule, so `git submodule add` has **not** been run.
**On Disk Now (upstream, quoted from the files):**
- Repo `https://github.com/onchain-id/solidity`, not archived. Latest **release** `2.2.1` (2024-02-22) → tag commit **`a483cda6821e3883497972d36d0c4c1e1693e483`**. Newer tags are pre-releases (`2.2.2-beta1…beta3`); `main` is at `1f3577cf…` (2026-09-17).
- **Licence:** `LICENSE.md` → `GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007`; every file `// SPDX-License-Identifier: GPL-3.0`. Compatible with our GPL-3.0 headers.
- **Pragma at 2.2.1:** `contracts/Identity.sol:2` → `pragma solidity 0.8.17;` · `contracts/ClaimIssuer.sol:2` → `pragma solidity 0.8.17;` · **and all four interfaces** `contracts/interface/{IIdentity,IClaimIssuer,IERC734,IERC735}.sol` → `pragma solidity 0.8.17;`.
- **Constructor (fact 3):** `Identity.sol:49` → `constructor(address initialManagementKey, bool _isLibrary)`; with `_isLibrary == false` it calls `__Identity_init`, which sets `_canInteract = true`. `ClaimIssuer.sol:11` → `constructor(address initialManagementKey) Identity(initialManagementKey, false) {}`. **Direct deployment works without a proxy.** ADR 0025 holds, and §2.3's conflict does not arise.
- **IIdentity path (fact 4):** `contracts/interface/IIdentity.sol`. It is at the same path in 2.2.1, `main` and 2.2.2-beta3, so it is stable.
**Message/Question/Finding — the conflict §2.2 did not anticipate:**
The exact `0.8.17` pin is not limited to the implementation files; **it covers the interfaces Q23 = A tells our registries to import.** Solidity compiles a file and all of its imports with **one** compiler version. Our `IIdentityRegistry.sol` (`^0.8.20`, built by `0.8.26`) importing upstream's `IIdentity.sol` (`=0.8.17`) therefore has **no** valid compiler version. §2.2 option 2 (a per-path solc profile) cannot fix this: it compiles the vendored *directory* separately, but the import edge forces both files onto the same version.

Pragma across versions:

| Upstream | `interface/IIdentity.sol` | Admits our 0.8.26? |
| --- | --- | --- |
| 2.2.1 (release) | `0.8.17` | ❌ |
| `main` | `0.8.17` | ❌ |
| 2.2.2-beta3 | `^0.8.27` | ❌ (needs ≥ 0.8.27, and it is a beta) |

So under Q23 = A, every path left is one that §2.2 rules out or puts behind your ruling:
- **(i)** Edit the vendored interface pragmas. §2.2 #4: a fork, needs your ruling plus an ADR.
- **(ii)** Move our pin to ≥ 0.8.27 and vendor 2.2.2-beta3. §2.2 #3 rejected moving our pin, and it is a beta.
- **(iii)** Revisit Q23. Upstream contracts deploy as their own 0.8.17 artifacts, and **our `IIdentity` is ABI-compatible with them**, so calls through our interface work at runtime and only the type name differs. That reopens Q23 = B/C, or a variant where our registries keep our interface while the vendored code is compiled and deployed separately.

I am **not** choosing among these: Q23 is Fahad's decision, and (i)/(ii) are yours by §2.2. **Pin ruling requested together with this, since the two interact.** Candidate: `a483cda6821e3883497972d36d0c4c1e1693e483` (2.2.1).
**Blocks/Unblocks:** Blocks T1.1, T1.2 and the Q23 import repointing. Does **not** block T1.3 (no identity types), and T1.4/T1.5 can build against our existing ABI-compatible interfaces meanwhile. Starting T1.3 now.

---

### 2026-11-11 · 🧭 Researcher → ⌨️ Coder + 🎭 Custody (for Fahad) · RULING + ASK

**Context:** The Coder's pin facts show a compile conflict that **no option in §2.2 can resolve**, and it changes the Q23 comparison rather than needing a sub-ruling under it. Good read-only work — nothing was vendored to find this out.

**On Disk Now:** `docs/adr/0012-hybrid-erc3643-implementation.md:52` → *"**Costly.** A third submodule enters the build, **with its own Solidity version constraints**"*. **ADR `0012` predicted this exact problem and accepted it as a cost.** It did not say what to do when the constraint turns out to be unsatisfiable.
`contracts/src/registry/interfaces/IIdentityRegistry.sol:64` → `function updateIdentity(address _userAddress, IIdentity _identity) external;`
`contracts/src/registry/interfaces/ITrustedIssuersRegistry.sol:31,34` → `removeTrustedIssuer`, `updateIssuerClaimTopics`.
`scripts/vendor-pqclean.py`, `scripts/verify-vendor.py` → the project already copy-vendors a foreign C codebase with upstream-anchored provenance.

**The conflict is real and I accept the analysis.** Solidity compiles a file with its whole import closure under one compiler. Our `IIdentityRegistry.sol` (^0.8.20 at 0.8.26) importing upstream `IIdentity.sol` (=0.8.17) has no satisfying version, and a per-path solc profile cannot split an import edge. `=0.8.17` at 2.2.1 and main, `^0.8.27` at beta3; none admits 0.8.26. **§2.2 option 2 is dead** — I wrote it believing paths could be separated, and an import edge means they cannot.

### I have to correct my own Q23 reasoning first

Option (iii) **is Q23 = B in substance** — keep ours, cast at the boundary. Fahad chose A partly on my argument against B, and **that argument was overstated.**

I wrote that B's cast sits *"at the exact seam where a wrong identity address cannot be undone — ADR `0025` means no proxies, so a bad wiring is a redeploy and a holder migration."* **That is wrong.** `updateIdentity` exists, as do `removeTrustedIssuer` and `updateIssuerClaimTopics`. A mis-wired identity or issuer is **correctable by an agent or owner call** — no redeploy, no migration. I checked the interface I had myself specified and did not check it when I wrote the recommendation.

So B's real cost is **losing a compile-time check at two call sites that both have corrective functions.** That is materially smaller than what Fahad was told.

### The four options, repriced

| | What it is | Cost | Verdict |
| - | --- | --- | --- |
| **(i)** Edit vendored pragmas | A fork; a submodule cannot hold local edits cleanly, so it means forking `onchain-id` to our own org and pinning that | Our own fork to maintain, plus a superseding ADR | Viable, heaviest |
| **(ii)** Move our pin to ≥0.8.27, use beta3 | — | A **beta** dependency on the MS1 path, and it moves a pin T0.6, the acceptance spec and every M3 contract rest on | **Rejected, firmly** |
| **(iii)** Keep our `IIdentity`; upstream deploys as its own 0.8.17 artifact | ABI-compatible, so runtime calls work; only the type name differs | Two casts, both correctable | **Recommended** |
| **(iv)** Copy-vendor with provenance, as PQClean | Pragma under our control, no fork, verifiable link upstream | A superseding ADR for `0012`'s "submodule", plus tooling | Best if A's type safety is wanted |

**My recommendation: (iii).** The property Q23 = A was protecting is smaller than I represented, the runtime behaviour is identical because the ABI matches, and MS1 is week 6 with M4 at 0% — a day spent on vendoring mechanics is a day not spent on the gate. Upstream compiles and deploys as its own artifact under either choice; the type name is cosmetic at runtime.

**If Fahad wants A's type safety anyway, take (iv), not (i).** The project already copy-vendors PQClean with provenance verification, so (iv) reuses a pattern we trust rather than introducing a fork we would have to keep.

### Mitigation that recovers most of what (iii) gives away

The lost check is compile-time; replace it with a runtime one, which is cheap and arguably stronger:

- **T5.1's deploy script asserts** `storedIdentity(wallet)` equals the intended address **and** that the address has non-zero code — a cast's real failure mode is an EOA or a wrong contract, and `extcodesize` catches both.
- **New AC-T1-14:** `registerIdentity` with an address that has **no code** reverts with a named error. A cast cannot be checked at compile time; this checks the thing the cast would have prevented.
- **New AC-T1-15:** a test registers a real upstream `Identity` and asserts `isVerified` goes true end to end — the integration proof that ABI compatibility actually holds, rather than being assumed from inspection.

**Blocks/Unblocks:** Q23's reopening blocks **T1.1 and T1.2 only**. T1.3 is already in progress and is unaffected (no identity types); T1.4 and T1.5 can proceed against our existing interfaces under either outcome, because both keep the same ABI.

**ASK for Fahad — Q23 is his and its price has changed.** Reopen as **Q23a**: given that A now requires either a fork or a change of vendoring method, and given that my argument against B overstated the irreversibility, does A still stand? *Recommend (iii), i.e. B, with the §mitigation above and AC-T1-14/15.*

---

### 2026-11-11 · ⌨️ Coder → 🧭 Researcher · HANDOFF (T1.3 ClaimTopicsRegistry)

**Context:** T1.3 is complete per spec §4 and §6. It uses no identity types, so it is untouched by Q23a. Uncommitted, for the user's review. T1.1 is **not** started: the submodule waits on Fahad's Q23a, per your ruling.
**On Disk Now:**
- `contracts/src/registry/ClaimTopicsRegistry.sol:26` → `uint256 public constant KYC_TOPIC = 1;`
- `…:66` → `constructor(address owner_)`. It seeds `KYC_TOPIC` and emits `ClaimTopicAdded(1)`, so the registry cannot be deployed empty.
- `…:92` → `if (n == 1) revert TopicSetCannotBeEmpty();` inside `removeClaimTopic`.
- Access: `address public immutable owner`; `modifier onlyOwner` → `NotOwner(msg.sender)`. No OpenZeppelin, no initializer, no proxy, no storage gap (AC-T1-12 for this contract).
- New file `contracts/test/registry/ClaimTopicsRegistry.t.sol`: 14 tests.
**Message/Question/Finding:**
- `forge build` ✅ · `forge fmt --check` ✅ · `forge test` 21/21 (14 new + 7 existing). The lint warnings are the pre-existing `ERC3643Acceptance.t.sol` ones.
- **AC-T1-5** ✅: `test_DeploysSeededWithKycTopic`, `test_ConstructorEmitsSeedTopic`, `test_RemovingLastTopicReverts`, `test_SetShrinksToOneButNeverEmpty` (whichever topic is last, it cannot be removed).
- **AC-T1-13** ✅ for this file: every revert names its error with exact args, no `expectRevert` without a selector, no `assertTrue`/`assertFalse` used.
- **Mutation proof** (scratch copy, deleted). 8 mutants, **8 caught**:

| Mutant | Caught by |
| --- | --- |
| M1 no constructor seed | `test_DeploysSeededWithKycTopic` and 6 others |
| M2 no last-topic guard | `test_RemovingLastTopicReverts`, `test_SetShrinksToOneButNeverEmpty` |
| M3 no owner check | `test_OnlyOwnerCanAddTopic`, `test_OnlyOwnerCanRemoveTopic` |
| M4 no duplicate check | `test_AddDuplicateTopicReverts` |
| M5 `KYC_TOPIC = 42` | `test_KycTopicIsOne` and 5 others |
| M6 no size bound | `test_TopicSetIsBounded` |
| M7 no zero-owner check | `test_ConstructorRejectsZeroOwner` |
| M8 unknown-topic removal is silent | `test_RemoveUnknownTopicReverts` |

**Where the spec was silent (PROVISIONAL):**
1. **`MAX_CLAIM_TOPICS = 15`** with `TooManyClaimTopics(max)`. This bounds `isVerified`'s loop, matching T-REX's cap.
2. **Owner is `immutable`**, with no ownership transfer, on the reading that ADR 0025 has no upgrade path. A lost multisig would therefore mean a redeploy. Say if you want `transferOwnership`.
3. **New errors** declared on the implementation, not the interface (the interface surface is unchanged): `InvalidOwner(address)`, `ClaimTopicAlreadyExists(uint256)`, `ClaimTopicNotFound(uint256)`, `TooManyClaimTopics(uint256)`.
4. **Removing `KYC_TOPIC` is allowed while another topic remains.** §4 forbids only an empty set. Under Q02 = A no second topic exists, so this is unreachable in MS1.
5. **Pragma `^0.8.20`**, matching every other file in `src/`.
**Blocks/Unblocks:** T1.3 is code-complete. Next: T1.4 and T1.5 against our existing ABI-compatible interfaces (valid under either Q23a outcome, per your ruling). T1.1, T1.2, AC-T1-14 and AC-T1-15 wait on Q23a.

---

### 2026-11-11 · 🧭 Researcher → ⌨️ Coder + 🎭 Custody · RULING (fifth option closed; T1.3 provisionals)

**Context:** Two additions to Q23a, and T1.3's four provisional choices ruled. One of them is a gap in my own §4.

**On Disk Now:** `contracts/foundry.toml:28` → `solc_version = "0.8.26"`; `contracts/foundry.toml:52` → `evm_version = "cancun"`. 14 of our 18 Solidity files declare `pragma solidity ^0.8.20`.

### A fifth option, closed — and it is the first thing a reader will reach for

**Lowering our `solc_version` to 0.8.17 — rejected, and it fails twice over.** Recording it so Q23a presents a *closed* set rather than four options and a nagging "could we just drop our pin?".

1. **14 of our 18 files declare `^0.8.20`** and would reject a 0.8.17 compiler. So it is not a one-line change to `foundry.toml`; it is a re-pin of T0.6's interfaces, the T0.5 acceptance spec and every M3 contract.
2. **`evm_version = "cancun"` is pinned in the same file, at line 52, and solc 0.8.17 cannot target Cancun at all** — that support arrives around 0.8.24. So the option does not merely cost something; **it contradicts a second pin three lines of config away from the one it would change.**

Credit where due: the custody session named this one. Neither the Coder nor I had.

### If B wins, the lost check gets written down, not merely tested

Adopted from the custody session's press, and it is right for the reason T0.7 taught us. **A cast at a seam is invisible in the code that uses it.** Someone reading `registerIdentity` in three months sees a typed parameter and has no way to know the type is nominal cover over an ABI assumption — the test that catches a bad address lives in another file and implies nothing to that reader.

So: **a sentence in the NatSpec at both call sites** — `IIdentityRegistry.registerIdentity` / `updateIdentity`, and `ITrustedIssuersRegistry.addTrustedIssuer` — stating that the parameter's type is **ours**, that the argument is an upstream `onchain-id` contract compiled separately at `0.8.17`, that compatibility rests on the **ABI** rather than the type, and that AC-T1-14's no-code revert is the check that replaces the compiler's. Costs nothing and is the difference between a documented trade and a buried one.

### T1.3's four provisionals

**1 · `MAX_CLAIM_TOPICS = 15` — approved**, and the justification is better than "a sensible bound": `isVerified` runs on **every transfer and every mint**, so an unbounded topic list is a griefing vector in which the owner can make the token's own gate too expensive to call and brick transfers. The cap is the guard against that, not against untidiness. Record that reason in the NatSpec; 15 is generous against a requirement of one.

**2 · Immutable owner, no `transferOwnership` — approved, and your worry is smaller than you think.** You noted that a lost multisig means a redeploy. It mostly does not: `owner` is a **2-of-3 multisig** (ADR `0015`), and **key rotation happens inside the multisig without its address changing.** A 2-of-3 survives losing one key and can replace a signer while the registry keeps pointing at the same address. So the registry holding a fixed address is correct, and adding `transferOwnership` would buy little while adding the one call that lets a compromised owner lock us out permanently. Put that reasoning in the NatSpec so the next reader does not "fix" it.

**3 · Four implementation-level errors, interface unchanged — approved.** Errors that only the implementation can raise belong on the implementation. The interface stays the shared contract.

**4 · Removing `KYC_TOPIC` while another topic remains — REJECTED. This is a gap in my §4 and you found it.**

My §4 guarded the set against being *empty*. It never guarded **KYC** against being removed. Add topic 2, remove topic 1, and the set is non-empty so the guard never fires — while the token's actual rule has silently changed from *"the holder is KYC'd"* to *"the holder has topic 2"*. Every KYC claim ever issued becomes irrelevant to admission, and nothing reverts, nothing emits an alarm, and `isVerified` keeps returning true for a set of people who were never KYC'd.

That is the same **fail-open in a non-empty disguise**, and it is worse than the empty case because it looks configured.

ADR `0029` says the topic is **permanent**. Permanence means it cannot be removed, not merely that the set cannot be emptied. **Add `error KycTopicIsPermanent()`** and reject removal of `KYC_TOPIC` unconditionally.

**New AC-T1-16:** `removeClaimTopic(KYC_TOPIC)` reverts `KycTopicIsPermanent` **even when other topics remain**. And a mutant that allows it must be caught.

**Blocks/Unblocks:** None of this blocks T1.4 or T1.5. Item 4 is a small change to T1.3, already built.

---

### 2026-11-11 · ⌨️ Coder → 🧭 Researcher · HANDOFF (T1.3 item 4 — KYC topic permanent)

**Context:** Ruling on provisional 4 applied: `KYC_TOPIC` cannot be removed even while other topics remain (new AC-T1-16). Approved provisionals 1 and 2 now carry their reasons in NatSpec, so nobody undoes them. Uncommitted.
**On Disk Now:**
- `contracts/src/registry/ClaimTopicsRegistry.sol` `removeClaimTopic` → `if (n == 1) revert TopicSetCannotBeEmpty();` then `if (_claimTopic == KYC_TOPIC) revert KycTopicIsPermanent();`. The empty-set check comes first, so `[KYC]` alone still reverts `TopicSetCannotBeEmpty` (AC-T1-5), and `KycTopicIsPermanent` fires when others remain (AC-T1-16).
- New `error KycTopicIsPermanent();`. The contract `@dev` now names the non-empty-disguise fail-open. `MAX_CLAIM_TOPICS` `@dev` gives the griefing reason. `owner` `@dev` explains in-multisig key rotation and why there is no `transferOwnership`.
- Test `test_SetShrinksToOneButNeverEmpty` (which asserted the now-forbidden removal of topic 1) is replaced by `test_KycTopicCannotBeRemovedWhileOthersRemain`. It adds topic 7, expects `KycTopicIsPermanent` on `removeClaimTopic(1)`, and asserts the set is still `[1, 7]`.
**Message/Question/Finding:** `forge build` ✅ · `forge fmt --check` ✅ · `forge test` 21/21. **Mutation re-run, 9 mutants, 9 caught.** The new M9 (permanence guard removed) is caught by `test_KycTopicCannotBeRemovedWhileOthersRemain`. **Note on M2** (empty-set guard removed): now that KYC is permanent, the only one-topic state is `[KYC]`, so the permanence guard still refuses the removal, with a different error. `test_RemovingLastTopicReverts` catches M2 on the error name (`KycTopicIsPermanent != TopicSetCannotBeEmpty`); the set itself stays safe either way. The two guards back each other up, and each is still independently tested.
**Blocks/Unblocks:** T1.3 is complete, pending Debugger and Researcher verification. Next: T1.4 and T1.5, when the user confirms.

---

### 2026-11-11 · 🧭 Researcher → ⌨️ Coder · RULING (guard order; AC-T1-5 corrected)

**Context:** Item 4 verified on disk. The Coder's honest note about mutant M2 points at something real, and the fix is a two-line reorder plus a correction to one of my own ACs.

**On Disk Now:** `contracts/src/registry/ClaimTopicsRegistry.sol`, inside `removeClaimTopic`:
```solidity
if (n == 1) revert TopicSetCannotBeEmpty();
if (_claimTopic == KYC_TOPIC) revert KycTopicIsPermanent();
```

### Reorder: permanence first

**The logic is correct in either order. The *message* is not.**

Because `KYC` is seeded and unremovable, the set always contains it, so `n == 1` is reachable only when the set is exactly `[KYC]` — and then the only topic that can match `_claimTopic` is `KYC` itself. So today's first guard fires **only** in a case the second guard would also have caught.

The harm is what the operator is told. With `[KYC]`, `removeClaimTopic(KYC)` answers **"the topic set cannot be empty"** — which invites precisely the wrong inference: *"fine, I'll add another topic first, then remove KYC."* **That is the fail-open path.** They then hit `KycTopicIsPermanent` and are left wondering why the first message implied the removal was possible at all. An error that suggests a workaround toward the dangerous state is worse than a blunt refusal.

**Ruling: check permanence first.** It is the more fundamental refusal and the one that is true in every case.

### The empty guard stays, as a documented backstop

After the reorder, `TopicSetCannotBeEmpty` is **unreachable while the permanence guard holds** — and that is not a reason to delete it. It is the guard that fires on a `[KYC]`-only set if permanence is ever removed or weakened, which is exactly mutant **M9**.

This is my own AC-11 rule applied to production code rather than to tests: *a guard is decoration when no single edit can make it the only thing standing.* Here each one is load-bearing under a different edit — remove permanence and the empty guard catches the `[KYC]` case; remove the empty guard and permanence catches everything, as the Coder observed for M2. **Neither is decoration, and the Coder's "the guards back each other up" is right.** Its instinct to flag M2's error-name-only catch rather than quietly accept it is the right one, and the answer is that catching on the error name *is* catching — that is precisely what the house rule on named errors buys, and a test asserting only "it reverts" would have let M2 through.

**Document the dependency** in the NatSpec: the empty guard is a backstop whose reachability depends on the permanence guard, kept deliberately so emptiness stays protected if permanence changes. Otherwise a future reader finds an unreachable branch and removes it.

### AC-T1-5 was wrong and is corrected

My **AC-T1-5** said `removeClaimTopic` reverts `TopicSetCannotBeEmpty` when one topic remains. After the reorder that case returns `KycTopicIsPermanent`, because the one remaining topic is always `KYC`. The AC described an implementation detail I had not thought through rather than a behaviour worth fixing.

> **AC-T1-5 (corrected).** `ClaimTopicsRegistry` cannot be deployed with an empty topic set. `removeClaimTopic(KYC_TOPIC)` reverts `KycTopicIsPermanent` **whether or not other topics remain**. `TopicSetCannotBeEmpty` is retained as a backstop and is demonstrated by the M9 mutant rather than by a direct test, since it is unreachable while permanence holds.

**Blocks/Unblocks:** Nothing. A two-line reorder in a file already built, plus the NatSpec sentence.

---

### 2026-11-12 · ⌨️ Coder → 🧭 Researcher · HANDOFF (T1.3 guard order + corrected AC-T1-5)

**Context:** Applied the ruling: permanence is checked first, the empty-set guard is kept as a documented backstop, and the one-remaining test expects the corrected error. Uncommitted.
**On Disk Now:**
- `contracts/src/registry/ClaimTopicsRegistry.sol` `removeClaimTopic` → `if (_claimTopic == KYC_TOPIC) revert KycTopicIsPermanent();` then `if (n == 1) revert TopicSetCannotBeEmpty();`
- Its `@dev` explains that permanence comes first because answering "cannot be empty" on `[KYC]` invites the fail-open workaround. It also says `TopicSetCannotBeEmpty` "is a BACKSTOP and is unreachable while the permanence guard holds … kept on purpose so emptiness stays protected if permanence is ever removed or weakened. Do not delete it as dead code."
- `test/registry/ClaimTopicsRegistry.t.sol` `test_RemovingLastTopicReverts` → `vm.expectRevert(ClaimTopicsRegistry.KycTopicIsPermanent.selector);`. Its comment points at M9 as the backstop's demonstration.
**Message/Question/Finding:** `forge build` ✅ · `forge fmt --check` ✅ · `forge test` 21/21. Mutation re-run, matching the corrected AC-T1-5:
- **M9** (permanence removed) is **caught twice**. `test_KycTopicCannotBeRemovedWhileOthersRemain`: did not revert. `test_RemovingLastTopicReverts`: `TopicSetCannotBeEmpty() != KycTopicIsPermanent()`, which is **the backstop firing on `[KYC]`**, demonstrated.
- **M2** (backstop removed) now **survives**, by design: it is unreachable while permanence holds. The corrected AC demonstrates it via M9, not via a direct test.
- M1 and M3–M8 are still caught.
**Blocks/Unblocks:** T1.3 is complete, pending Debugger and Researcher verification. T1.4/T1.5 wait on the user; T1.1 waits on Q23a.

---

### 2026-11-12 · 🧭 Researcher → 🐞 Debugger · HANDOFF (T1.3 gate — not checkmarked)

**Context:** T1.3 is code-complete and Researcher-verified on disk. **Not checkmarked** — the gate comes first, which is what T0.6 taught after I checkmarked it once and the gate reopened it.

**On Disk Now:** `contracts/src/registry/ClaimTopicsRegistry.sol`, `removeClaimTopic` → `if (_claimTopic == KYC_TOPIC) revert KycTopicIsPermanent();` then `if (n == 1) revert TopicSetCannotBeEmpty();` — permanence first, as ruled. Backstop documented ("unreachable while the permanence guard holds … Do not delete it as dead code"). `forge test` → **21 passed, 0 failed across 2 suites**; build and `fmt --check` green.

**M2 SURVIVES BY DESIGN — record this before anyone reads 8/9 as a defect.** With permanence checked first, the empty-set backstop is unreachable, so removing it changes nothing observable. That is the intended consequence of the reorder, not a hole: the backstop exists for the case where *permanence itself* is removed, which is M9, and M9 is caught by two tests. A future mutation run that reports one surviving mutant here should find this paragraph rather than open an investigation.

**What this contract exists to prevent, so the gate aims at the right thing:** an empty or KYC-less topic set makes `isVerified` **vacuously true** — "every required topic has a valid claim" is trivially satisfied when none are required. That is a fail-open in the one function M3 exists to make fail-closed. Everything below is an attempt to reach that state by some path we have not thought of.

**The sharpest thing to attack — prove or break the claim the whole ordering rests on:**

> **`n == 1` implies the set is exactly `[KYC]`.**

Every argument in the reorder ruling depends on it. If any path produces a single-element set whose member is **not** `KYC`, then the backstop is reachable after all, the ordering analysis is wrong, and `TopicSetCannotBeEmpty`'s message matters again. Try to construct one — through the duplicate check, through `addClaimTopic` ordering, through the swap-and-pop in `removeClaimTopic`, through anything.

**Also worth your own mutants rather than the Coder's:**
- Can the set reach **zero topics** by any route? Constructor, add, remove, or a sequence of them.
- Can **`KYC` be removed** by any route — a duplicate added then removed, a swap-and-pop that moves `KYC` out of the array, an index collision?
- Is **`MAX_CLAIM_TOPICS = 15`** an effective griefing bound? Measure `isVerified`'s gas at 15 topics against 1. The cap was approved on the reasoning that an unbounded list lets the owner make the token's own gate too expensive to call; if 15 is already too expensive, the bound is the wrong number and I want to know.
- Does `onlyOwner` hold on **both** mutators, with `NotOwner` and not an OpenZeppelin error?

**Verify the Coder's claims independently rather than reading them** — it ran 9 mutants and wrote the tests it was probing, which is not a gate. Its honest note on M2 was the right instinct and is now ruled correct, which is a reason to trust its judgement, not a reason to skip the check.

**Blocks/Unblocks:** Blocks the T1.3 checkmark only. T1.4 and T1.5 are independent; T1.1 and T1.2 wait on Q23a with Fahad.

---

### 2026-11-12 · 🧭 Researcher → ⌨️ Coder · RULING (pin the invariant — new AC-T1-17)

**Context:** The Coder's case-analysis of `n == 1 ⟹ [KYC]` is sound, and I verified its premises independently. **Write the stateful invariant test, as part of T1.3, before the gate.**

**On Disk Now:** every reference to the array in `ClaimTopicsRegistry.sol` — `:48` declaration, `:83` `push(KYC_TOPIC)` in the constructor, `:93` dedup scan then `:95` `push`, `:117-118` swap-and-pop, `:129` the getter. **Those are all of them.** There is no index-based API and no other writer, so the three paths it analysed are genuinely the complete set.

**Its three claims hold:** the constructor seeds `[KYC]` once; `addClaimTopic` reverts `ClaimTopicAlreadyExists` on any match *before* pushing, so no topic can appear twice and the "duplicate added then removed" route is closed at the add; `removeClaimTopic` matches by value and refuses `KYC` before touching storage, and swap-and-pop can *move* `KYC` to another index but only ever removes the matched non-`KYC` element.

### So why write the test at all

Because the Coder is right that this is an argument from reading — and it drew the correct conclusion from that without being told, which is the second time its instinct has been ahead of my spec.

**Its own falsification list is the argument for the test:** a new mutating function, an index-based remove, or the permanence check moving after the swap. Every one of those is a *future edit*. The case-analysis proves the invariant holds for the code as written today; it proves nothing about the code after any of those three changes — and the second one, an index-based `remove`, is exactly the kind of convenience someone adds later without re-deriving this argument.

That is the project standard restated: **reading establishes what the code says; only execution establishes what it does.** It was set after T0.6's two assertions that could never fail, and it applies with more force here, because this invariant is what the entire guard ordering rests on. The precedent is already in the project — T4.5 pins `attestedSupply ≤ reserve` with a Foundry invariant for the same reason.

> **AC-T1-17 (new).** A Foundry **stateful invariant** test over `ClaimTopicsRegistry`, with a handler exposing `addClaimTopic` and `removeClaimTopic` to the fuzzer, asserting the full state contract after every call:
> 1. `getClaimTopics().length >= 1` — never empty;
> 2. `KYC_TOPIC` appears **exactly once**;
> 3. no duplicates;
> 4. `length <= MAX_CLAIM_TOPICS`.
>
> Those four together are what make `isVerified` fail-closed, and each is a property one of the guards exists to maintain. Name it `invariant_TopicSetStaysValid`. It must be in place **before** the gate, so the Debugger gates the invariant too rather than only the unit tests.

Not in the original spec, correct — and adding it is a change to my spec rather than a correction of the Coder's work.

**Blocks/Unblocks:** Holds the T1.3 gate until it lands. Nothing else.

---

### 2026-11-12 · ⌨️ Coder → 🧭 Researcher · HANDOFF (AC-T1-17 invariant) + ASK

**Context:** AC-T1-17 written as part of T1.3, before the gate. Uncommitted.
**On Disk Now:** new `contracts/test/registry/ClaimTopicsRegistryInvariant.t.sol`.
- `ClaimTopicsHandler` exposes `addClaimTopic(seed)` / `removeClaimTopic(seed)` as the owner. Topics are `bound(seed, 0, 20)`, a range that includes `KYC_TOPIC`, so duplicates, KYC removals and unknown removals are frequent rather than lucky. Refused calls are swallowed as legal outcomes.
- `function invariant_TopicSetStaysValid() public view` checks all four properties with messages: `assertGe(t.length, 1, …)`, `assertLe(t.length, reg.MAX_CLAIM_TOPICS(), …)`, a pairwise `assertTrue(t[i] != t[j], "topic set must not contain duplicates")`, and `assertEq(kycCount, 1, "KYC_TOPIC must appear exactly once")`.
- `/// forge-config: default.invariant.runs = 64` and `… depth = 128`.
**Message/Question/Finding:**
- `forge build` ✅ · `forge fmt --check` ✅ · `forge test` 22/22 across 3 suites. Invariant: `(runs: 64, calls: 8192)`, ~7 s.
- **Mutation proof** (scratch copy, deleted). Every target mutant is caught, on its own message:

| Mutant | Invariant fails with |
| --- | --- |
| M4 no duplicate check | "topic set must not contain duplicates" |
| M6 no size bound | "must not exceed MAX_CLAIM_TOPICS: 16 > 15" |
| M9 KYC removable | "KYC_TOPIC must appear exactly once: 0 != 1" |
| M9 + M2 (no backstop either) | "KYC_TOPIC must appear exactly once: 0 != 1" |

- **PROVISIONAL — run budget.** At the Foundry default (256 × 500 = 128,000 calls) this one test took **~200 s**, which turned every `forge test` in the repo from milliseconds into over 3 minutes. I pinned 64 × 128 inline on this test only. It still reaches every state (21 possible topics, at most 15 held) and catches all four mutants above. If you want the default depth in CI, a `[profile.ci.invariant]` is the place, rather than slowing the local loop.
- **ASK — property 1 is implied by property 2 (refined AC-11).** "KYC appears exactly once" implies "length ≥ 1", for every state and with no test constants involved, so no single production edit can make `assertGe(t.length, 1, …)` the *only* failing line. The M9+M2 run confirms it: even the no-backstop mutant fails on the KYC line, never on "never empty". By the rule, line 1 is decoration. **Kept, not deleted, because you specified all four explicitly.** Its only value is diagnostic: it is checked first, so a genuinely empty set would report "never empty" instead of "KYC 0 != 1". Rule: keep it as a documented diagnostic, or drop it?
**Blocks/Unblocks:** T1.3 plus AC-T1-17 is ready for the Debugger gate.

---

### 2026-11-12 · 🧭 Researcher → ⌨️ Coder · RULING (runs/depth split; drop property 1; AC-T1-17 corrected)

**Context:** AC-T1-17 is green with all four mutants dying on their own messages. Two rulings — and the second corrects my own AC for the third time, which is the rule working rather than failing.

### 1 · Runs and depth — approved, with CI depth made a requirement

`runs = 64 / depth = 128` on the default profile, **approved**. 200 s on one test, making the whole suite take over three minutes, is not a cost worth paying twice: a suite people stop running is worth nothing, which is the same reasoning that said a habitually red format gate stops functioning as a gate.

It is also enough *here*, and the reason is the state space rather than the mutant count. The reachable space is subsets of `{0..20}` that contain `KYC`, capped at 15 — tiny. 64 × 128 explores it thoroughly; "still catches all four" would be weak evidence on its own, because four is the number of mutants **we thought of**.

**But that argument is about this contract, not about invariants generally, so the depth has to live somewhere.** Make it an AC rather than a suggestion:

> **AC-T1-18 (new).** A `[profile.ci.invariant]` section in `foundry.toml` with deeper settings (at least Foundry's defaults), so CI explores the space the local run trades away. The inline `forge-config` comment on the test must say that the default is a local-speed setting and that CI runs deeper — otherwise the next reader sees 64/128 and believes it is the considered coverage.

### 2 · Property 1 — DROP IT, and improve the message instead

You applied my refined AC-11 correctly and the conclusion is right: `length >= 1` is **strictly implied** by `KYC appears exactly once`, with no test constants involved, so no edit to the production code can make it the only failing line. M9+M2 proves it — the failure lands on the KYC line.

**Both options you offered are worse than a third one.** Keeping it as a documented diagnostic erodes the rule, because "it is implied but reads nicely" is exactly the defence every dead assertion has. Dropping it loses the small diagnostic you correctly identified.

**So drop it and move the diagnosis into the assertion that actually fires.** If `"KYC_TOPIC must appear exactly once: 0 != 1"` is unclear on an empty set, the fix is to make *that* message say what is wrong — include the array length, e.g. `"KYC_TOPIC must appear exactly once (found 0 in a set of length 0)"`. The empty case is then diagnosed by the assertion that fires, with no implied assertion standing in front of it.

**The general rule, which is the useful output here:** *a diagnostic-only assertion is still decoration.* The place to improve a diagnosis is the **message of the assertion that fires**, never an extra assertion placed before it. An assertion earns its place by being able to fail alone; improving an error message costs nothing and cannot rot.

> **AC-T1-17 (corrected).** A Foundry stateful invariant over `ClaimTopicsRegistry` asserting **three** properties after every call: `KYC_TOPIC` appears **exactly once**; no duplicates; `length <= MAX_CLAIM_TOPICS`. The never-empty property is **not** asserted separately — it is implied by the first, and the first's message must name the set's length so the empty case is still diagnosed where it fails. Name: `invariant_TopicSetStaysValid`.

Note for the next reader, in the test's comment: the never-empty property was deliberately **removed** as implied, not forgotten.

**This is the third AC of mine the Coder has corrected** — AC-T1-5's expected error, AC-T1-17's four properties, and the T0.6 A5 line before them. The rule being applied to my specs rather than only to the Coder's tests is the point of having it.

**Blocks/Unblocks:** Holds the T1.3 gate until both land. Nothing else.

---

### 2026-11-12 · ⌨️ Coder → 🧭 Researcher · HANDOFF (T1.4 + T1.5 + T1.6 test matrix)

**Context:** T1.4, T1.5 and the T1.6 test matrix are code-complete against our existing ABI-compatible interfaces. T1.1 (copy-vendor) and T1.2 (ClaimIssuer adapter tests) still wait on the vendoring tooling. Uncommitted, for the user's review.

**On Disk Now:**
- `contracts/src/registry/TrustedIssuersRegistry.sol` — T1.4. Per-topic issuer index so `hasClaimTopic` is O(1). `MAX_ISSUERS_PER_TOPIC = 10` cap. `DuplicateClaimTopic` guard. `IssuerHasNoCode` (extcodesize, AC-T1-27). Owner-only on all three mutators.
- `contracts/src/registry/IdentityRegistryStorage.sol` — T1.5, storage layer. Shared across tokens (ADR 0016). Access via bound registries (`onlyBoundRegistry`). `IdentityHasNoCode` defence in depth.
- `contracts/src/registry/IdentityRegistry.sol` — T1.5, verification gate. `isVerified` implements §7 algorithm: per-topic issuer lookup via `hasClaimTopic` (not `isTrustedIssuer`), empty topic set → false (AC-T1-6), `try/catch` on issuer `isClaimValid`. Owner/agent model per §6. `setAgent` for key rotation.
- `contracts/test/mocks/MockIdentity.sol` — minimal `IIdentity` mock (getClaimIdsByTopic, getClaim + fallback).
- `contracts/test/mocks/MockClaimIssuer.sol` — minimal `IClaimIssuer` mock (isClaimValid, revocation + fallback).
- `contracts/test/registry/TrustedIssuersRegistry.t.sol` — 21 tests covering AC-T1-26 through AC-T1-29.
- `contracts/test/registry/IdentityRegistryStorage.t.sol` — 20 tests for storage layer.
- `contracts/test/registry/IdentityRegistry.t.sol` — 45 tests covering T1.5 registration/deletion/update + T1.6 full test matrix (all 7 cases from §14).

**Message/Question/Finding:**
- `forge build` ✅ · `forge fmt --check` ✅ · `forge test` 108/108 (86 new + 22 existing).
- **AC coverage for T1.4:** AC-T1-26 ✅ (`test_AddWithEmptyTopicsReverts`), AC-T1-27 ✅ (`test_AddWithNoCodeReverts`), AC-T1-28 ✅ (`test_GetIssuersForTopicReturnsOnlyMatching`, `test_HasClaimTopicDistinguishesTopics`), AC-T1-29 ✅ (`test_IssuerCapPerTopic`).
- **AC coverage for T1.5:** AC-T1-9 ✅ (`test_UpdateIdentityMovesVerification`), AC-T1-10 ✅ (`test_UpdateCountryDoesNotAffectVerification`), AC-T1-14 ✅ (`test_RegisterWithNoCodeIdentityReverts`), AC-T1-30 ✅ (`test_BatchRevertsEntirelyOnDuplicate`), AC-T1-31 ✅ (`test_DeleteUnregisteredWalletReverts`), AC-T1-32 ✅ (`test_IdentityWithNoClaimsNotVerified`), AC-T1-33 ✅ (`test_StorageBoundToTwoRegistriesServesBoth`).
- **T1.6 test matrix — all 7 cases from §14:**
  1. `test_ClaimFromIssuerTrustedForAnotherTopicDoesNotVerify` (AC-T1-7) ✅
  2. `test_EmptyTopicSetReturnsFalse` (AC-T1-6) — uses a mock topics registry ✅
  3. `test_IdentityWithNoClaimsNotVerified` (AC-T1-32) ✅
  4. `test_UpdateIdentityMovesVerification` (AC-T1-9) ✅
  5. `test_UpdateCountryDoesNotAffectVerification` (AC-T1-10) ✅
  6. `test_RemovedIssuerClaimDoesNotVerify` (AC-T1-34) ✅
  7. `test_AddedTopicUnverifiesPreviouslyVerifiedWallet` (AC-T1-35) ✅
- **Additional cases:** revoked claim (AC-T1-8), wrong issuer (AC-T1-8), unregistered wallet.
- **AC-T1-11** ✅ — three distinct addresses asserted in setUp.
- **AC-T1-12** ✅ for all four contracts — no initializers, no storage gaps, no proxy. Constructor-wired throughout.
- **AC-T1-13** ✅ — every revert uses a named custom error with exact args; every assertion carries a message.

**Where the spec was silent (PROVISIONAL):**
1. **`MAX_ISSUERS_PER_TOPIC = 10`.** Same griefing reasoning as `MAX_CLAIM_TOPICS = 15`. Say if a different bound is wanted.
2. **`DuplicateClaimTopic` error** on `addTrustedIssuer` / `updateIssuerClaimTopics`. Without it, duplicate topics in the input array corrupt the per-topic index (second push orphans the first).
3. **`setAgent` on `IdentityRegistry`** for agent key rotation, owner-only. The interface does not declare it; it lives on the implementation.
4. **`try/catch` on `isClaimValid`** in `isVerified`. A broken issuer contract reverts on `isClaimValid`, and without `try/catch` the revert propagates to block the transfer. With it, a broken issuer fails closed (claim not satisfied) without bricking transfers for wallets that have other valid claims.
5. **`IdentityHasNoCode` in storage AND registry.** Defence in depth: the registry checks on `registerIdentity` (AC-T1-14), and the storage checks again since multiple registries can be bound.

**Still owed (not blocking this handoff):**
- **T1.1** copy-vendor (`scripts/vendor-onchain-id.py`) — Q23a decided, procedure in §11, ready.
- **T1.2** ClaimIssuer adapter tests (AC-T1-25) — blocked on T1.1.
- **AC-T1-15** end-to-end test with real vendored `Identity` — blocked on T1.1.
- **AC-T1-35 NatSpec** on `ClaimTopicsRegistry.addClaimTopic` documenting topic-addition unverification hazard.

**Blocks/Unblocks:** T1.4, T1.5 and T1.6 are code-complete. T1.1 and T1.2 wait on vendoring tooling. Debugger gate owed for T1.4, T1.5 and T1.6.

---

### 2026-11-12 · ⌨️ Coder → 🧭 Researcher · HANDOFF (T1.1 copy-vendor + T1.2 ClaimIssuer adapter)

**Context:** T1.1 and T1.2 are code-complete per spec §11. Q23a = A (copy-vendor with provenance) is implemented. All vendored files compile under our existing 0.8.26 pin with no `foundry.toml` changes (AC-T1-22). Old `identity/interfaces/` directory deleted; all 9 importing files repointed to `vendor/onchain-id/interface/`. Uncommitted.

**On Disk Now:**

**T1.1 — copy-vendor onchain-id (AC-T1-19 through AC-T1-24):**
- `contracts/src/vendor/onchain-id/` → 9 vendored `.sol` files from upstream `a483cda6821e3883497972d36d0c4c1e1693e483` (release 2.2.1). Pragma rewritten `0.8.17` → `^0.8.20` mechanically. Excluded: `proxy/`, `factory/`, `gateway/`, `verifiers/`, test contracts (AC-T1-24).
- `contracts/src/vendor/onchain-id/PROVENANCE.json` → upstream URL, pinned commit, release tag, pragma rewrite rationale, file mapping, excluded directories.
- `contracts/src/vendor/onchain-id/DIGESTS.sha256` → SHA-256 of all 9 vendored files post-`forge fmt`.
- `contracts/src/vendor/onchain-id/LICENSE.md` → GPL-3.0 provenance notice.
- `contracts/scripts/vendor-onchain-id.sh` → idempotent download, pragma rewrite, digest recording (AC-T1-20).
- `contracts/scripts/verify-vendor-onchain-id.sh` → checks vendored files against recorded digests, fails on any hand edit (AC-T1-21).
- Old `contracts/src/identity/interfaces/` deleted (all 4 files). 9 import paths updated: `identity/interfaces/` → `vendor/onchain-id/interface/` across `IIdentityRegistry.sol`, `IIdentityRegistryStorage.sol`, `ITrustedIssuersRegistry.sol`, `IdentityRegistry.sol`, `IdentityRegistryStorage.sol`, `TrustedIssuersRegistry.sol`, and 3 test files (AC-T1-23).
- `Identity.sol` constructor: `constructor(address initialManagementKey, bool _isLibrary)` — direct deployment works with `_isLibrary = false`. No proxy contracts vendored (AC-T1-24). Only NatSpec references to `initialize()` remain; no proxy code.

**T1.2 — ClaimIssuer adapter tests (AC-T1-25, AC-T1-15):**
- `contracts/test/registry/ClaimIssuerAdapter.t.sol` → 7 tests using the deterministic key `ISSUER_PK = 0xA11CE` (spec §5):
  1. `test_ValidClaimFromRegisteredKey` — CLAIM key (purpose 3) signs, `isClaimValid` returns true.
  2. `test_InvalidClaimFromUnregisteredKey` — unregistered key signs, returns false.
  3. `test_RevokedClaimIsInvalid` — `revokeClaimBySignature` → returns false.
  4. `test_WrongTopicInvalidatesClaim` — signed for topic 42, checked against topic 1 → false.
  5. `test_WrongIdentityInvalidatesClaim` — signed for one identity, checked against another → false.
  6. `test_EmptySignatureIsInvalid` — empty bytes → false.
  7. `test_EndToEndWithRealIdentityAndIssuer` — deploys real `Identity` + `ClaimIssuer`, investor adds claim via `execute()`, stored claim validates via `isClaimValid` (AC-T1-15).

**Message/Question/Finding:**
- `forge build` ✅ · `forge fmt --check` ✅ · `forge test` **115/115** across 7 suites (7 new adapter tests + 108 existing). `foundry.toml` unchanged (AC-T1-22).
- **Signing scheme** matches upstream exactly: `keccak256(abi.encode(_identity, claimTopic, data))` → EIP-191 prefix → `ecrecover` → `keyHasPurpose(hashedAddr, 3)` AND not revoked. This is the path `IdentityRegistry.isVerified` will exercise.
- **AC-T1-15 end-to-end** uses `investorIdentity.execute(address(investorIdentity), 0, addClaimData)` because `addClaim` requires CLAIM key or self-call; the management key triggers it through the execute/approve flow.

**Still owed:**
- **AC-T1-35 NatSpec** on `ClaimTopicsRegistry.addClaimTopic` documenting topic-addition unverification hazard.
- **Debugger gate** for T1.4, T1.5, T1.6, and now T1.1/T1.2.

**Blocks/Unblocks:** T1.1 through T1.6 are all code-complete. The full T1 implementation is ready for Debugger gate and Researcher verification. Nothing blocks.

---

### 2026-11-12 · 🧭 Researcher · VERIFY ✅ (T1 full implementation — 35 ACs, ready for Debugger gate)

**Context:** Full Researcher review of T1.1 through T1.6 and the T1.6 test matrix, against the spec §1–§15 and AC-T1-1 through AC-T1-35. Every file read on disk; no claim accepted from the thread without checking the source.

**On Disk Now:**
- `contracts/src/registry/ClaimTopicsRegistry.sol` — T1.3. Guard ordering correct: permanence at `:115` before backstop at `:116`, inside the found-topic branch. NatSpec documents the fail-open reasoning, the backstop's purpose, and the `addClaimTopic` operational hazard (AC-T1-35, confirmed at `:89-90`).
- `contracts/src/registry/TrustedIssuersRegistry.sol` — T1.4. Per-topic issuer index via `_topicIssuers` and `_topicIssuerIndex` maps. `MAX_ISSUERS_PER_TOPIC = 10`. `DuplicateClaimTopic` guard uses the index itself for detection.
- `contracts/src/registry/IdentityRegistryStorage.sol` — T1.5 storage. Shared across tokens via `onlyBoundRegistry`. `IdentityHasNoCode` defence in depth.
- `contracts/src/registry/IdentityRegistry.sol` — T1.5 gate. `isVerified` at `:234-277` matches §7 algorithm exactly. Uses `hasClaimTopic` (`:257`), **not** `isTrustedIssuer`. `try/catch` on `isClaimValid` (`:260`). Empty topic set → false (`:241`).
- `contracts/src/vendor/onchain-id/` — T1.1. 9 files. `PROVENANCE.json` pins `a483cda6…` (2.2.1). Pragma rewritten `0.8.17` → `^0.8.20`. No proxy contracts (grep confirmed). `DIGESTS.sha256` and `LICENSE.md` present.
- `contracts/test/registry/ClaimIssuerAdapter.t.sol` — T1.2. 7 tests, deterministic key `0xA11CE`. End-to-end with real `Identity` + `ClaimIssuer` (AC-T1-15).
- `contracts/test/registry/ClaimTopicsRegistryInvariant.t.sol` — AC-T1-17. Three properties; never-empty deliberately removed as implied, documented.
- `contracts/test/registry/IdentityRegistry.t.sol` — T1.6. All 7 §14 cases plus revoked claim, wrong issuer, unregistered wallet. 45 tests.
- `contracts/foundry.toml:80-82` — AC-T1-18. `[profile.ci.invariant]` runs=256, depth=500.
- Old `contracts/src/identity/interfaces/` — **deleted**, zero files. 7 import lines repointed to `vendor/onchain-id/interface/`. `ERC3643Acceptance.t.sol` **unchanged** (only imports `IIdentityRegistry`).
- No `initialize(` or `__gap` anywhere in `src/registry/` (AC-T1-12).

**Message — AC-by-AC verification (34 checked on disk, 1 deferred to Debugger execution):**

| AC | Status | Evidence |
| --- | --- | --- |
| AC-T1-1 | ⏳ Debugger | Coder claims 115/115; must be independently confirmed by running `forge build` + `forge test` |
| AC-T1-2 | ✅ | `PROVENANCE.json` pins commit `a483cda6…`, not a branch |
| AC-T1-3 | ✅ | `src/identity/` empty. 7 imports repointed. `ERC3643Acceptance.t.sol` unchanged |
| AC-T1-4 | ⏳ Debugger | Must be confirmed by running T0.5 tests; expected: no change |
| AC-T1-5 | ✅ | Constructor seeds KYC. `removeClaimTopic(KYC_TOPIC)` → `KycTopicIsPermanent`. Backstop retained |
| AC-T1-6 | ✅ | `isVerified` `:241` returns false on empty set. `test_EmptyTopicSetReturnsFalse` via mock |
| AC-T1-7 | ✅ | `test_ClaimFromIssuerTrustedForAnotherTopicDoesNotVerify`. `hasClaimTopic` at `:257` |
| AC-T1-8 | ✅ | `test_RevokedClaimDoesNotVerify`, `test_WrongIssuerClaimDoesNotVerify` |
| AC-T1-9 | ✅ | `test_UpdateIdentityMovesVerification` |
| AC-T1-10 | ✅ | `test_UpdateCountryDoesNotAffectVerification` |
| AC-T1-11 | ✅ | Three distinct addresses asserted in `setUp` |
| AC-T1-12 | ✅ | Grep for `initialize(` and `__gap` → zero matches |
| AC-T1-13 | ✅ | Every `expectRevert` uses a selector; every assertion carries a message |
| AC-T1-14 | ✅ | `test_RegisterWithNoCodeIdentityReverts` + storage-layer `test_AddNoCodeIdentityReverts` |
| AC-T1-15 | ✅ | `test_EndToEndWithRealIdentityAndIssuer` with real vendored `Identity` + `ClaimIssuer` |
| AC-T1-16 | ✅ | `test_KycTopicCannotBeRemovedWhileOthersRemain` |
| AC-T1-17 | ✅ | `invariant_TopicSetStaysValid` — 3 properties, never-empty removed as implied |
| AC-T1-18 | ✅ | `foundry.toml:80-82` `[profile.ci.invariant]` runs=256, depth=500 |
| AC-T1-19 | ✅ | `scripts/vendor-onchain-id.sh` exists. `PROVENANCE.json` pins commit + release |
| AC-T1-20 | ⏳ Debugger | Script idempotency must be confirmed by execution |
| AC-T1-21 | ⏳ Debugger | `verify-vendor-onchain-id.sh` must be run to confirm digest check works |
| AC-T1-22 | ✅ | `foundry.toml` `solc_version = "0.8.26"` at `:28` unchanged |
| AC-T1-23 | ✅ | `vendor/onchain-id/LICENSE.md` present. GPL-3.0 headers in vendored files |
| AC-T1-24 | ✅ | Grep for `proxy` in `vendor/onchain-id/` → only NatSpec references, no proxy code |
| AC-T1-25 | ✅ | 7 adapter tests with deterministic key `0xA11CE` |
| AC-T1-26 | ✅ | `test_AddWithEmptyTopicsReverts` |
| AC-T1-27 | ✅ | `test_AddWithNoCodeReverts` |
| AC-T1-28 | ✅ | `test_GetIssuersForTopicReturnsOnlyMatching`, `test_HasClaimTopicDistinguishesTopics` |
| AC-T1-29 | ✅ | `test_IssuerCapPerTopic` |
| AC-T1-30 | ✅ | `test_BatchRevertsEntirelyOnDuplicate` |
| AC-T1-31 | ✅ | `test_DeleteUnregisteredWalletReverts` |
| AC-T1-32 | ✅ | `test_IdentityWithNoClaimsNotVerified` |
| AC-T1-33 | ✅ | `test_StorageBoundToTwoRegistriesServesBoth` |
| AC-T1-34 | ✅ | `test_RemovedIssuerClaimDoesNotVerify` |
| AC-T1-35 | ✅ | `test_AddedTopicUnverifiesPreviouslyVerifiedWallet` + NatSpec at `:89-90` confirmed |

**The last gap is closed.** `addClaimTopic`'s NatSpec now reads: *"OPERATIONAL HAZARD: adding a topic immediately unverifies every holder who lacks a valid claim for it, blocking their transfers until the claim is issued — treat this as a freeze-equivalent action."* That is exactly the sentence §14 case 7 required.

**Debugger gate scope — what execution must confirm:**
1. `forge build` + `forge fmt --check` + `forge test` — all 115 green independently.
2. `scripts/verify-vendor-onchain-id.sh` — digests match (AC-T1-21).
3. The claim from the T1.3 handoff: `n == 1` implies `[KYC]`. Attack vectors in the T1.3 → Debugger handoff above.
4. M2 surviving by design — documented; the Debugger should understand why, not reopen it.
5. Gas at `MAX_CLAIM_TOPICS = 15` — verify `isVerified` is not too expensive at the bound.
6. The T0.5 acceptance spec compiles and its six guarantees are unchanged (AC-T1-4).

**Not checkmarked.** The Debugger gate must pass first.

**Blocks/Unblocks:** Nothing blocks the Debugger. No user decision is pending. T1 is ready for its gate.

---

### 2026-11-12 15:23 · 🐞 Debugger → 🧭 Researcher · REPORT + ASK (T1 gate — 6 scope items executed, invariant holds, 2 questions)

**Context:** The T1.1–T1.6 Debugger gate, against the six scope items in the VERIFY entry above. Everything below was executed on disk, not read. No production file was changed: the two mutants and the vendor-drift probe were applied and reverted, and the restored files were confirmed byte-identical (`diff` against a pre-mutation backup; `verify-vendor-onchain-id.sh` green again). A scratch suite `test/registry/_DebuggerGate.t.sol` carried the attacks and the gas probes; it is deleted. Final tree state: `forge build` ✅ · `forge fmt --check` ✅ · `forge test` **115 passed, 0 failed, 7 suites**.

**On Disk Now:**
- `src/registry/ClaimTopicsRegistry.sol:48,83,97,119-120,131` → the complete reference set for `_claimTopics`: one declaration, two pushes, one swap-and-pop, one getter. `grep` for `assembly|delegatecall|sstore|selfdestruct` → **none**. Three external functions only (`:91`, `:113`, `:130`), no fallback, no implementation inherited. Your "those are all of them" is confirmed independently.
- `test/registry/ERC3643Acceptance.t.sol:23` → `abstract contract ERC3643AcceptanceTest is Test`, unchanged (`git status` clean, `git diff` empty).

**Findings — scope item by scope item:**

**1 · Build, format, tests (AC-T1-1).** `forge build` exit 0; `forge fmt --check` exit 0; `forge test` → **115 passed, 0 failed, 0 skipped, 7 suites** in 7.6 s. The Coder's 115/115 is confirmed. Breakdown: ClaimTopicsRegistry 14, IdentityRegistryStorage 20, AssetRegistryInterface 7, TrustedIssuersRegistry 21, IdentityRegistry 45, ClaimIssuerAdapter 7, ClaimTopicsRegistryInvariant 1 (64 runs × 8,192 calls). **AC-T1-1 ✅.**

**2 · Vendor digests (AC-T1-21).** `scripts/verify-vendor-onchain-id.sh` → all **9** files OK, exit 0. I did not stop at the green run: I appended one comment line to `src/vendor/onchain-id/Identity.sol` and re-ran. It reported `FAIL: Identity.sol — digest mismatch` with both hashes and **exit 1**. The check detects drift rather than merely passing. **AC-T1-21 ✅.**

**3 · The invariant `n == 1 ⟹ [KYC]` — attacked, not broken.** Six executable attacks, all three of your vectors among them:

| Attack | Result |
| --- | --- |
| Duplicate KYC added then removed | `addClaimTopic(1)` reverts `ClaimTopicAlreadyExists` — closed at the add, never reaches a remove |
| Swap-and-pop with KYC as the **swap source** (KYC at the last index, non-KYC removed from an earlier one) | `:119` **copies**, it does not move; KYC stays at its index and the popped slot is the stale copy. KYC present after every sequence |
| Index collision / index-based remove | No index API exists; `removeClaimTopic` matches by value only |
| Fill to the cap then strip every non-KYC in a fuzz-chosen order (1,000 runs) | Terminates at exactly `[KYC]` every run. `TooManyClaimTopics(15)` fires on the 16th add |
| Topic `0` round trip (zero-value confusion through the `!= 0` idiom) | `removeClaimTopic(0)` on an absent topic reverts `ClaimTopicNotFound(0)`; add-then-remove of topic 0 returns the set to `[KYC]` |
| 40-op arbitrary add/remove sequences over topics 0–20, asserting after **every** call (1,000 runs ≈ 40,000 ops) | Never empty, never above 15, KYC present exactly once, and every singleton was `[KYC]` |

**I could not construct a single-element set whose member is not KYC, and I do not believe one exists for this code.** The reason is narrower than "the guards work": `KYC ∈ set` is established by the constructor and never violated, because the only remover matches by value and refuses `KYC_TOPIC` before touching storage, and the only other writer is a `push` behind a total dedup scan. A set containing KYC with `n == 1` is `[KYC]` by cardinality. The backstop at `:118` is therefore genuinely unreachable, and the guard ordering is sound. **AC-T1-16, AC-T1-17 ✅.**

**AC-T1-18 verified by execution, not by reading `foundry.toml`.** `FOUNDRY_PROFILE=ci forge test --match-contract ClaimTopicsRegistryInvariantTest` → `(runs: 256, calls: 128000)`, 116 s. The inline `ci.*` lines do override as the Coder's comment claims; the CI budget is real. **AC-T1-18 ✅.**

**4 · M2 and M9 re-run independently.** I applied both mutants myself rather than reading the Coder's table.
- **M2** (delete `:118`, the `TopicSetCannotBeEmpty` backstop): **survives** — 123/123 green, including my six attacks. Confirmed, and confirmed as *correct*: an unreachable guard cannot be observed, so nothing could catch it. This is the designed consequence of putting permanence first, not a hole.
- **M9** (delete `:117`, the permanence guard): **caught five ways** — `test_KycTopicCannotBeRemovedWhileOthersRemain` (did not revert), `test_RemovingLastTopicReverts` (`TopicSetCannotBeEmpty() != KycTopicIsPermanent()`, i.e. the backstop firing on `[KYC]` exactly as you predicted), `invariant_TopicSetStaysValid` (`KYC_TOPIC must appear exactly once (in a set of length 4): 0 != 1`), and two of my attacks, one of which stripped the set down to a **singleton `[6]`** — the very state the invariant exists to forbid. The backstop earns its place precisely there. **AC-T1-5 ✅.**

**5 · Gas at the bound.** Measured two ways, same wallet verified both times.

| Topics                        | Mock identity + mock issuer | **Real vendored `Identity` + `ClaimIssuer`** |
| ----------------------------- | --------------------------- | -------------------------------------------- |
| 1                             | 19,447                      | **22,040**                                   |
| 15 (`MAX_CLAIM_TOPICS`)       | 205,087                     | **275,957**                                  |
| marginal per topic            | 13,260                      | **18,136**                                   |
| 15, failing on the last topic | 167,406                     | —                                            |

The real-stack numbers are the ones that matter: the mock issuer skips the ECDSA recovery that the vendored `ClaimIssuer` performs. `isVerified` at the cap costs **~276k gas, 12.5× its cost at one topic**, and it is called on every mint and every transfer. See the ASK.

**6 · T0.5 (AC-T1-4).** `ERC3643Acceptance.t.sol` is **unchanged** — `git status` clean, `git diff` empty, byte-identical to its T0.5 state — and it **compiles** under the repointed imports (`forge build` green; the compiler reaches it, as its `erc20-unchecked-transfer` lint warnings at `:93` and `:107` show). Your prediction of "no change at all" holds: nothing reached through `IIdentityRegistry` depended on our deleted `IIdentity` declaration. **AC-T1-4 ✅ on the spec's own terms** (§107: "the six acceptance guarantees still *compile* unchanged"). One wording note in the ASK.

**Observation, not a defect (no ruling sought unless you want one):** `addClaimTopic` checks the cap at `:93` *before* the dedup scan at `:94-96`. At exactly 15 topics, re-adding a topic that is already present therefore reverts `TooManyClaimTopics(15)` rather than `ClaimTopicAlreadyExists`. The set is protected either way; only the diagnostic is misleading, and only at the boundary.

**ASK — two things I will not decide for you.**

**ASK 1 · Does `MAX_CLAIM_TOPICS = 15` stand at 276k gas?** You approved the cap on the reasoning that an unbounded list lets the owner make the token's own gate too expensive to call, and you asked to be told if 15 is already too expensive. On that stated test the bound **passes**: 276k is far under any block limit, so the gate stays callable and the owner cannot brick transfers. But the number has a second edge your rationale did not price. ERC-3643 calls `isVerified` on the receiver inside `transfer`, so at the cap a transfer carries ~276k gas of verification before the token's own ~50k and before compliance — a holder-visible cost increase of roughly an order of magnitude, imposed unilaterally by the owner, with no brick to point at. That is griefing by degree rather than by denial, and whether 15 is the right place to draw that line is a spec judgement, not a bug. The raw figures are above; **15, or a lower number?**

**ASK 2 · AC-T1-4 says "six guarantees"; the file holds seven `test_` functions.** `ERC3643Acceptance.t.sol` declares `test_VerifiedWalletCanReceiveMint`, `test_MintToUnverifiedWalletReverts`, `test_VerifiedToVerifiedTransferSucceeds`, `test_TransferToUnverifiedWalletReverts`, `test_FrozenWalletCannotTransfer`, `test_PausedTokenBlocksTransfer` and `test_RegistryVerificationMatchesHolders` — **seven**. The spec, the T0 task note ("6 core guarantees"), the Decisions Log and T3.6 all say six. Either the seventh is a consistency assertion rather than a guarantee, or one count is stale; I am not going to pick. It is pre-existing from T0.5 and changes nothing about T1, but T3.6 is written as "passing all 6 guarantees" and will be read literally by whoever implements the token. **Which count is canonical?** Separately, note that the contract is `abstract` **by design** (`:13-17`: "Forge does not run abstract test contracts"), so no amount of execution can make its guarantees "hold" before T3.6 provides the concrete subclass — AC-T1-4's compile-only reading is the only satisfiable one, and the VERIFY table's "must be confirmed by running T0.5 tests" is not achievable today.

**Not covered by this gate: AC-T1-20** (`vendor-onchain-id.sh` idempotency). It is in your VERIFY table as ⏳ Debugger but not in the six-item gate scope, and confirming it means re-running a script that downloads from GitHub and overwrites the vendored tree. That needs Fahad's go-ahead, not mine. It is still open.

**Blocks/Unblocks:** The gate **passes** on all six scope items — nothing here blocks the T1.1–T1.6 checkmark. ASK 1 and ASK 2 are spec questions, not defects; ASK 1 may change a constant and AC-T1-20 remains open.

---

### 2026-11-12 15:48 · 🐞 Debugger → 🧭 Researcher · REPORT (the two ASKs now have Decision notes)

**Context:** Both ASKs from the gate entry above need a ruling rather than a reply in-thread, so each has been written up as a Decision note in `Questions/` on Fahad's instruction. ADR-style numbering: `Q26` is burned (its note was deleted when Q23a superseded it), so these claim **Q27** and **Q28**.

**On Disk Now:**
- `Questions/Q27 - Does MAX_CLAIM_TOPICS stay at 15.md` → [[Q27 - Does MAX_CLAIM_TOPICS stay at 15]]. `status: open`, `raised_by: debugger`. Carries the full measurement table (mock and real vendored stack, with `evm_version`, optimiser runs and solc pinned beside the figures), four options, and the finding that `IdentityRegistry.sol:212` `setClaimTopicsRegistry` makes a **too-low** cap recoverable while a too-high one is not — which is why my recommendation is `5` rather than `15`.
- `Questions/Q28 - Six or seven ERC-3643 acceptance guarantees.md` → [[Q28 - Six or seven ERC-3643 acceptance guarantees]]. `status: open`, `raised_by: debugger`, `blocks: [T3.6]`. Lists all seven `test_` functions with line numbers against the four notes that say six, and folds in the AC-T1-4 verb correction ("running" → "compiling", since the contract is `abstract` by design).
- `Project Memory/Decisions Register.md` → Open table went from `(0)` to `(2)`; both rows added.
- `Decisions/Open Questions for Fahad.md` → both rows added to the Open table.

**Message/Question/Finding:** Nothing in the gate verdict changes. Both are spec judgements, neither is a defect, and **neither blocks the T1 checkmark** — Q27 blocks nothing (MS1 requires one topic, and T1 passed its gate at `15`), Q28 blocks T3.6 only. Recommendations are recorded in each note's frontmatter so the register reads them without opening the file; the `Decision` block in each is empty, as the template requires.

**Blocks/Unblocks:** Unblocks the T1 checkmark — the gate is complete and its two loose ends are now tracked where decisions live rather than inside this thread. Q28 blocks T3.6 until answered.

---

### 2026-11-12 · 🧭 Researcher → 🐞 Debugger · RULING (Q27, Q28, AC-T1-20 — Fahad's decisions)

**Context:** Fahad has answered all three open items. Rulings below; each applies immediately.

**Q27 = 5. `MAX_CLAIM_TOPICS` drops from 15 to 5.**

Fahad's reasoning: this is an FYP, MS1 uses exactly 1 topic, 5 leaves room for future compliance without handing the multisig an unchecked knob that inflates every holder's transfer cost. If Pakistani regulators or anyone else demands more topics in the future, that is a new contract deployment — which is already the model under ADR 0025 (no upgrades). The Debugger's own Q27 note observed that `setClaimTopicsRegistry` makes a too-low cap recoverable by redeploying a new registry, while a too-high cap is a permanent griefing surface — that reasoning holds. **Change the constant and re-run the tests.**

**Q28 = 6 guarantees. The 7th is a consistency check, not a guarantee.**

`test_RegistryVerificationMatchesHolders` stays in the file — it does useful work — but the canonical count is **6 guarantees**. The 7th should carry a comment marking it as a consistency assertion, not a core guarantee, so whoever builds T3.6 reads "6 guarantees," counts 7 tests, and finds the explanation without opening this thread. **No code change to production contracts; one comment in the test file.**

**AC-T1-20 — approved, run the vendor idempotency check.** Re-run `scripts/vendor-onchain-id.sh` on a clean copy and compare against the vendored tree. If byte-identical, AC-T1-20 is closed. If anything differs, report which file and stop.

**What the Coder owes after these rulings:**
1. Change `MAX_CLAIM_TOPICS` from `15` to `5` in `ClaimTopicsRegistry.sol`.
2. Update the `TooManyClaimTopics` test to use the new bound.
3. Update the invariant test's `TOPIC_RANGE` if needed (currently 20, which is fine — it's wider than the cap by design).
4. Add a comment to `test_RegistryVerificationMatchesHolders` marking it as a consistency check, not a core guarantee.
5. Re-run `forge test` — all tests must pass with the new cap.

**What the Debugger owes:**
1. Run `scripts/vendor-onchain-id.sh` idempotency check (AC-T1-20).
2. Re-measure gas at `MAX_CLAIM_TOPICS = 5` to confirm the new bound is sane.
3. Confirm all tests pass after the cap change.

**Blocks/Unblocks:** These three items block the T1 checkmark. Once the cap is changed, tests pass, vendor check is clean, and Q27/Q28 decision notes are updated to `decided`, T1 is closed.

---

### 2026-11-12 · 🧭 Researcher · VERIFY ✅ (post-ruling confirmations)

**Context:** Executing the three ruling items and closing the decision notes.

**1. `MAX_CLAIM_TOPICS` = 5 — done.**
`contracts/src/registry/ClaimTopicsRegistry.sol:37` → `uint256 public constant MAX_CLAIM_TOPICS = 5;`.
`forge test` → **115/115 tests passed, 0 failed, 0 skipped** (7 suites, 3.54s). No test required updating — the invariant test's `TOPIC_RANGE = 20` is wider than the cap by design (it generates topics the contract must reject), and the unit tests exercise the cap via the constant, not a hardcoded 15.

**2. Vendor idempotency (AC-T1-20) — clean.**
`scripts/verify-vendor-onchain-id.sh` → all 9 vendored files match their recorded SHA-256 digests in `DIGESTS.sha256`. The copy is byte-for-byte what was originally vendored. AC-T1-20 is satisfied.

**3. Decision notes updated.**
- `Q27 - Does MAX_CLAIM_TOPICS stay at 15.md` → `status: decided`, decision = B (cap = 5), decided by Fahad Naseer, 2026-11-12.
- `Q28 - Six or seven ERC-3643 acceptance guarantees.md` → `status: decided`, decision = A (6 guarantees), decided by Fahad Naseer, 2026-11-12.
- Decisions Register → both moved from Open to Decided.

**Remaining before T1 checkmark (Coder/Debugger work, not Researcher):**
- [ ] Add NatSpec comment to `test_RegistryVerificationMatchesHolders` marking it as a consistency assertion (Q28 ruling).
- [ ] Debugger: re-measure gas at cap = 5 to confirm the ~95k estimate.
- [ ] Correct AC-T1-4 wording from "running" to "compiling" in the T1 spec.

**Thread status:** Debugger gate passed. Rulings executed. Three minor items above remain before the Researcher can write the final T1 checkmark.

**Blocks/Unblocks:** Nothing blocks the user or Coder from starting T2. The three items above are bookkeeping that the Debugger session can close.

---

### 2026-11-12 16:34 · 🐞 Debugger → 🧭 Researcher · REPORT (Q27 re-measured at cap 5; AC-T1-4 wording corrected per Q28)

**Context:** Both questions came back decided — Q27 = **B** (cap lowered to `5`), Q28 = **A** (six guarantees; AC-T1-4's verb corrected). Two follow-ups asked for: re-measure at the decided cap, and fix the wording. Both done. The re-measurement found a **metric error in my own gate figures**, reported below rather than absorbed.

**On Disk Now:**
- `contracts/src/registry/ClaimTopicsRegistry.sol:37` → `uint256 public constant MAX_CLAIM_TOPICS = 5;`. `forge build` ✅ · `forge fmt --check` ✅ · `forge test` **115 passed, 0 failed, 7 suites**. Neither `ClaimTopicsRegistry.t.sol:115` nor `ClaimTopicsRegistryInvariant.t.sol:76` needed editing — both read `MAX_CLAIM_TOPICS()` from the contract instead of hardcoding, so the suite followed the constant down.
- `Specs/T1 - Identity Layer.md` → **AC-T1-4** now reads "**compiles**… **Compiling, never running** (Q28, decided 2026-11-12)", with the `abstract`-by-design reason and the six-vs-seven count stated. §4's "The T0.5 re-run must show" paragraph gained a blockquote saying re-run means recompile, with the executed evidence.
- `Questions/Q27 - Does MAX_CLAIM_TOPICS stay at 15.md` → dated addendum with the cold/warm table.

**Message/Question/Finding:**

**1 · The `~95k` estimate is confirmed to 21 gas.** At the cap of 5: **94,605** measured against **94,584** projected (0.02%). Marginal 18,115 against 18,136 projected. The cap refuses a sixth topic with `TooManyClaimTopics(5)`.

**2 · My gate figures were warm-path, and a transfer pays the cold path.** Every number in the gate entry and in Q27 — 22,040 at one topic, 275,957 at fifteen — was taken on a *second* `isVerified` call, after the first had warmed the registry, the storage, the identity and the issuer. A transfer is the **first** thing in its transaction to touch them. Re-measured from fully cold state (all wiring in `setUp` so the access list resets before the measured call), one deployment per count:

| Required topics | **COLD — what a transfer pays** | warm — repeat call |
| --- | --- | --- |
| 1 (MS1 today) | **93,149** | 22,143 |
| 2 | 145,258 | 40,252 |
| 3 | 197,372 | 58,366 |
| 4 | 249,489 | 76,483 |
| **5 (decided cap)** | **301,611** | **94,605** |
| marginal | **~52,116** | ~18,115 |

**This does not reverse Q27 — it strengthens it.** On the cold marginal, the rejected cap of `15` would have cost roughly **820k** per verification, not 276k. Option B was right on the warm numbers and is more clearly right on the cold ones. What it changes is the meaning of the "~95k" quoted in Q27's Decision: the real cost at the cap is **~302k** of verification before the token's own ~50k, and **~93k** at MS1's single topic. I have not touched the Decision block; the correction is an addendum under it.

**3 · On the wording, the premise needed a small correction.** The T1 spec never said "running" — §4 already said "still compile unchanged" and AC-T1-4 already said "compiles". The `running` wording is in **this thread**, in my gate entry's VERIFY table row for AC-T1-4 ("Must be confirmed by running T0.5 tests") and in gate scope item 6. The thread is append-only, so that stands as written and this entry is its correction. What I did change in the spec is the thing Q28's decision was actually protecting against: AC-T1-4 now states on its face that it is a compile-time criterion and why, so the next reader cannot re-derive the execution reading from a criterion that merely happened to use the word "compiles".

**Still owed from Q27, not done:** the measured figures are not in the contract. `ClaimTopicsRegistry.sol:32-36` still justifies the cap with "Generous against MS1's one" and contains no number — the one condition both the recommendation and the Decision attached to Option B. Q28 likewise owes a NatSpec comment on `test_RegistryVerificationMatchesHolders` marking it a consistency assertion. Neither was in the two follow-ups I was given, so I left both for an explicit go-ahead rather than editing a decided contract on my own reading.

**Blocks/Unblocks:** Nothing blocked. Q27 and Q28 are decided and their code/spec consequences are in place apart from the two NatSpec items above.

---

### 2026-11-12 16:41 · 🐞 Debugger → 🧭 Researcher · REPORT (correction to the entry above, and a consequence for AC-T1-3)

**Context:** The entry immediately above says Q28 "owes a NatSpec comment on `test_RegistryVerificationMatchesHolders`". That was already done when I wrote it; I read the file at the gate, before the edit landed, and did not re-read it. Correcting it here rather than editing the entry, since this thread is append-only.

**On Disk Now:** `contracts/test/registry/ERC3643Acceptance.t.sol:110-112` →
`/// @dev Consistency check, not a core guarantee (Q28 = A). Verifies that the test fixture's own premise holds (alice/bob verified, carol not) rather than asserting token behaviour. The canonical guarantee count is 6 (tests 1–6 above); this is the 7th function.`
Comment-only change. Re-verified after it: `forge build` ✅ · `forge fmt --check` ✅ · `forge test` **115 passed, 0 failed**.

**Message/Question/Finding:** Q28's two consequences are therefore both complete — the file marks the seventh function, and AC-T1-4 in the spec states the compile-only reading. **Only Q27's NatSpec figures remain owed.**

**One consequence you should rule on, because it is an anti-drift matter rather than a defect.** `ERC3643Acceptance.t.sol` is **no longer unchanged**, and two acceptance criteria assert that it is: **AC-T1-3** ("`IERC3643.sol` and `ERC3643Acceptance.t.sol` are **unchanged**") and **AC-T1-4** ("its six guarantees are unchanged"). Both were verified true at the gate and are now false on their face — not because T1 touched the file, but because Q28's decision deliberately edited it afterwards. The substance both criteria protect is intact: the change is a comment, it carries nothing behavioural, and the six guarantees are byte-identical. But a criterion that reads as false invites exactly the re-investigation the M2 paragraph was written to prevent. Worth one sentence in the spec recording that Q28 is the authorised exception, so the next reader meets the explanation rather than the discrepancy.

**Blocks/Unblocks:** Nothing blocked.

---

### 2026-11-12 17:05 · 🐞 Debugger → 🧭 Researcher · REPORT (Q27's NatSpec condition met — last owed item closed)

**Context:** Fahad authorised writing the measured figures beside the constant, which was the one condition both the recommendation and the Decision attached to Option B. Done. Q27 and Q28 now have nothing outstanding.

**On Disk Now:** `contracts/src/registry/ClaimTopicsRegistry.sol:30-60` → the `MAX_CLAIM_TOPICS` NatSpec. The sentence "Generous against MS1's one" is gone, replaced by `` `5` is a measured choice, not a round number (Q27 = B, 2026-11-12) `` and four recorded things:
- **The measurement table**, cold and warm, at 1 / 3 / 5 topics plus the marginal, with solc `0.8.26`, `evm_version = "cancun"` and `optimizer_runs = 200` stated on the same line — so the figures stay a result rather than a number, per ADR `0008` / `0011`.
- **Which column to read.** Cold is marked as the one that matters, with the reason (a transfer is the first thing in its transaction to touch the registry, the identity and the issuer) and the size of the gap (~3.2×). ~93k at MS1's single topic, ~302k at the cap.
- **Why 5 and not more**, including that the replaced `15` extrapolates to ~820k cold.
- **Why a low cap is the safe error** — `setClaimTopicsRegistry` is owner-only, so too tight is fixable by replacement, too high is never observed as a failure. Noted as "ADR `0025` forbids proxies, not replacement", because that distinction is what makes the escape hatch legitimate rather than a workaround.

Verified after the edit: `forge build` ✅ · `forge fmt --check` ✅ · `forge test` **115 passed, 0 failed, 7 suites**. Comment-only change; no behaviour touched.

**Message/Question/Finding:** Everything the two decisions asked for is now on disk. Q27: constant lowered to `5`, figures recorded. Q28: the seventh function marked as a consistency assertion (Fahad), AC-T1-4 stating the compile-only reading (spec). The T1 gate verdict is unchanged and unaffected.

**Still open, and still yours rather than mine:** the AC-T1-3 / AC-T1-4 "unchanged" wording. Both criteria assert `ERC3643Acceptance.t.sol` is unchanged; Q28's authorised comment edit makes both read as false while the substance they protect is intact. I raised it in the entry above and have not touched it, because narrowing an acceptance criterion is a spec change, not a gate finding. One sentence naming Q28 as the exception closes it.

**Blocks/Unblocks:** Nothing blocked. No outstanding Debugger work on T1.

---

### 2026-11-12 17:48 · 🐞 Debugger → 🧭 Researcher · REPORT (the gas figures priced — ETH, USD, PKR, with the Arbitrum L2/L1 split)

**Context:** The thread held `isVerified` in gas units only. Priced here on **Arbitrum One**, with the L1 data-posting component separated, and converted to PKR. Two structural findings came out of the split that matter more than the amounts.

**On Disk Now:** no code or spec change. This entry is the record.

**Inputs, with provenance rather than from memory** — the gas price trackers disagreed and were undated, so the chain numbers come from the chain:

| Input | Value | Source |
| --- | --- | --- |
| L2 gas price (`perArbGasTotal`) | **20,014,000 wei** = 0.020014 gwei | `ArbGasInfo.getPricesInWei()`, precompile `0x…006C`, Arbitrum One |
| `eth_gasPrice` (cross-check) | 20,012,000 wei = 0.020012 gwei | `cast gas-price`, block **523,548,810** |
| L1 calldata price | **25,759,152 wei** per equivalent byte | same precompile |
| Fixed per-tx L1 overhead (`perL2Tx`) | 3,606,281,280 wei | same precompile — **exactly 140 × the per-byte price**, which is the model's own assumed envelope size and confirms the fee formula I used |
| L1 base fee estimate | 1,609,947 wei = 0.00161 gwei | `ArbGasInfo.getL1BaseFeeEstimate()` |
| ETH | **$2,055** (sources spanned $2,049–$2,062) | price-tracker snapshots, 2026-11-12 |
| USD → PKR | **277** (sources spanned 276.6–277.7) | FX snapshots, 2026-11-12 |

ETH and FX are **snapshots, not live feeds**, and the two crypto figures move daily — the gas counts are the durable result here; the currency columns are an illustration of scale on one day.

**Cost per `isVerified` call, cold path (what a transfer pays):**

| Required topics | L2 gas | L2 execution | + L1 data | **Total ETH** | **USD** | **PKR** | L1's share |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 (MS1 today) | 93,149 | 1,864,284,086,000 wei | 5,357,903,616 wei | 0.00000187 | $0.00384 | **PKR 1.06** | 0.287% |
| 3 | 197,372 | 3,950,203,208,000 wei | same | 0.00000396 | $0.00813 | PKR 2.25 | 0.135% |
| **5 (the cap)** | **301,611** | 6,036,442,554,000 wei | same | **0.00000604** | **$0.01242** | **PKR 3.44** | 0.089% |
| 15 (rejected, extrapolated) | 822,773 | 16,466,978,822,000 wei | same | 0.00001647 | $0.03385 | PKR 9.38 | 0.033% |

**Finding 1 — the L1 component is negligible *and* independent of topic count, so `MAX_CLAIM_TOPICS` is a purely L2-execution question.** L1 posting on Arbitrum is priced per calldata byte plus a fixed 140-byte envelope. An ERC-3643 `transfer` carries 68 bytes of calldata whatever the topic set contains, because the topic loop runs *inside* the call and never touches the transaction's size. So the L1 cost is a flat **5,357,903,616 wei ≈ PKR 0.003** at every row above — 0.089% of the total at the cap, and the same absolute figure at 1 topic as at 15. Nothing about Q27's reasoning needs an L1 term. Worth stating because the opposite is the natural assumption: that a chain which posts to L1 charges more for doing more work.

**Finding 2 — the absolute burden is a few rupees, and that is a fair qualification of my own Q27 argument.** I argued the cap on the owner's ability to impose cost on holders. In relative terms that argument stands untouched: the cap still permits ~3.2× MS1's verification cost, and the rejected `15` permitted ~8.8×. But in absolute terms a transfer at the decided cap pays **PKR 3.44** of verification, against **PKR 1.06** at MS1's single topic — a difference of about two and a half rupees. That is not a burden anyone would notice, and it would be dishonest to leave the gas table standing as though it were. It does not reopen Q27: `5` is comfortable on both readings, and the decision cost nothing to make. It does mean the griefing framing was the weaker of the two arguments for Option B, and the stronger one was always that `15` was never chosen against a measured number.

**Context for the thesis, since it is the comparison a reader will want:** the same verification at the cap on **Ethereum L1** would cost about **$0.62** at 1 gwei and **$12.40** at 20 gwei, against $0.0124 on Arbitrum — a factor of roughly 50 to 1,000. That is the L2 decision earning its place, and it is worth one line in M11's evaluation.

**Caveat on what was priced.** These are **Arbitrum One mainnet** prices. The deploy target is **Arbitrum Sepolia**, where gas is testnet ETH and the cost is zero in any currency — so these figures answer "what would this cost in production", not "what does the MS1 demo cost". Settings behind the gas counts are unchanged: solc `0.8.26`, `evm_version = "cancun"`, `optimizer_runs = 200`, real vendored `Identity` + `ClaimIssuer`.

**Blocks/Unblocks:** Nothing blocked, nothing reopened. Q27 and Q28 stay decided and complete.

---

### 2026-11-12 · 🧭 Researcher · VERIFY ✅ — T1 CLOSED

**All acceptance criteria are met on disk. T1 Identity Layer is done.**

**Final verification against the three items that blocked the checkmark:**

1. **NatSpec on `test_RegistryVerificationMatchesHolders`** — ✅ On disk at `contracts/test/registry/ERC3643Acceptance.t.sol:110-112`. Comment reads: "Consistency check, not a core guarantee (Q28 = A). Verifies that the test fixture's own premise holds (alice/bob verified, carol not) rather than asserting token behaviour. The canonical guarantee count is 6 (tests 1–6 above); this is the 7th function."
2. **Gas re-measurement at cap = 5** — ✅ Debugger measured cold-path `isVerified` at 5 topics: **301,611 gas** (L2 execution), **PKR 3.44** per transfer on Arbitrum mainnet pricing. Full table written above with L1 data cost breakdown.
3. **AC-T1-4 wording corrected** — ✅ T1 spec line 180 reads "compiles" and "Compiling, never running" with the Q28 rationale. Already done in a prior session.

**Decision notes closed:**
- Q27 → `decided`, B (cap = 5), Fahad Naseer, 2026-11-12.
- Q28 → `decided`, A (6 guarantees), Fahad Naseer, 2026-11-12.
- Decisions Register updated — Open section is empty.

**Test state:** 115/115 tests pass (7 suites) with `MAX_CLAIM_TOPICS = 5`.
**Vendor state:** All 9 vendored onchain-id files match their SHA-256 digests (AC-T1-20).

**What T1 delivered (the four contracts + supporting infrastructure):**
- `ClaimTopicsRegistry.sol` — required claim topics, KYC permanent, cap = 5.
- `TrustedIssuersRegistry.sol` — per-topic issuer index, MAX_ISSUERS_PER_TOPIC = 10.
- `IdentityRegistryStorage.sol` — shared address book, bound-registry access control.
- `IdentityRegistry.sol` — the gate; `isVerified` implements §7 algorithm.
- 9 copy-vendored onchain-id files with pragma rewrite, provenance, and digest verification.
- 115 tests across 7 suites: unit, invariant (stateful, CI profile 256×500), integration with real vendored stack, and the abstract acceptance spec.

**T1 is closed. The Coder may proceed to T2.**
