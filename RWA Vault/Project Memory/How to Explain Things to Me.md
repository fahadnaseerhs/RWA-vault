---
tags: [rwa-vault, process, explanation]
updated: 2026-10-27
---
# How to Explain Things to Me

The house rule for every explanation on this project — in chat, in a review, in a vault note. Set by the user on **2026-10-27**, after the first M3 [[T6 - Provider Onboarding Console|T6]] explanation opened at the wrong altitude and did not land.

> *"I prefer the reality and the real scenario and the what's the practical. Then I have the visualization, then I will think, then I can easily move towards the forward and the decisions."*

## The order — always this order

| # | Step | What it sounds like |
| - | ---- | ------------------- |
| 1 | **Where we are in reality** | What actually exists right now, in the world. Two sentences. No file names. |
| 2 | **What it will be when it works** | The scene: who is sitting there, what they're holding, what they click, what they see happen. A story, not a spec. **This is the visualisation.** |
| 3 | **Why it has to exist** | What goes wrong in the real world without it. |
| 4 | **The mechanics** | *Now* the flow, the contracts, the interfaces, the files, the maths. |
| 5 | **The decisions** | What needs deciding, and what each choice costs. |

## The rule behind the rule

**You cannot evaluate a decision until you can picture the thing.** Starting at the architecture layer — interfaces, predicates, acceptance criteria — means the explanation arrives as noise and has to be asked for twice.

So: **open with a scene, not a definition.**

- ✅ "A man walks into the office with a gold bar in a briefcase."
- ❌ "M3's done-condition is that a provider onboards a gold lot unaided."

Both are about T6. Only one of them can be pictured.

## Practical rules

- **No jargon before step 4.** Where a term is unavoidable, spell it out on first use — *attestation* = a signed note from the custodian saying what is actually in the vault.
- **Use the project's concrete objects**, not abstractions: a gold bar, a custodian's vault, a provider, an investor's phone, a screen with four steps. Not "the asset", "the entity", "the actor".
- **Depth is still wanted** — the technical detail is not the problem, its *position* is. Put it after the picture and label it as the mechanics.
- **Numbers and names stay exact** once you're in step 4. Intuition first does not mean vague later.

## Where this already applies

The `Understanding/` folder in the [[Module Folder Template|module template]] is built on this order on purpose — `00 - What is Module N` → core concepts → `What's Been Built`, intuition to detail. This note makes the same order binding on conversation, not just on notes.

Up: [[Project Memory]] · Related: [[Working Conventions]], [[Agents - Workflow]], [[Module Folder Template]]
