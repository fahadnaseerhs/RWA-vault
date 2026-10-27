---
tags: [rwa-vault, agents, protocol]
updated: 2026-10-27
---
# 📜 Agents Protocol — Master Interaction Standard

> **"Now you will work in this structure."**  
> This protocol governs how human teammates (Fahad, Hassan, Fawaz) and AI agents (Researcher, Coder, Debugger) interact, make decisions, log progress, and maintain the vault as a reliable single source of truth.

---

## 1. The Three Roles

| Role | Emoji | Primary Ownership | Definition of Success |
|---|---|---|---|
| **Researcher** | 🧭 | **What & Why** | Formulates unambiguous specs, acceptance criteria (AC), verifies code against predicates, **sole authority to checkmark tasks**. |
| **Coder** | ⌨️ | **How** | Implements strictly against interface definitions, writes tests, achieves clean compiles and passing test vectors. |
| **Debugger** | 🐞 | **Closing the Gap to Green** | Diagnoses test failures. Solves mechanical bugs; **routes ambiguous behavior back to Researcher** via structured questions. |

---

## 2. The Agent Communication Thread ("The Visible Chat")

Instead of creating ad-hoc, untracked notes across the vault whenever agents interact, every active task has a designated **Thread Note** located in `Module <N>/Threads/Thread - <Task>.md`.

### Entry Format
Every interaction in the thread MUST use this standard envelope:

```markdown
### YYYY-MM-DD HH:MM · 🎭 [From Agent] → 🎭 [To Agent] · [ACTION]
**Context:** <Short reference to task, failing test, or interface clause>
**On Disk Now:** `<filepath>:<line>` → `<exact code or output>`
**Message / Finding:** <Crisp, factual explanation>
**Action Needed:** <Explicit question or required fix>
**Status / Unblocks:** <What moves next>
```

### Action Types
- `PLAN` — Researcher posts the implementation plan, file touch-list, and Acceptance Criteria.
- `HANDOFF` — Coder posts compiled code + test run logs to Debugger or Researcher.
- `REPORT` — Debugger reports verification findings, mutation test runs, or parity checks.
- `ASK` — Debugger or Coder asks Researcher for clarification on ambiguous behavior or edge cases.
- `RULING` — Researcher answers an `ASK` with an authoritative design decision (and creates/links an ADR if non-obvious).
- `VERIFY ✅` — Researcher marks the task verified and checked off.

---

## 3. The 4 Universal Vault Invariants

1. **Frontmatter as Single Source of Truth:**
   Status lives in YAML frontmatter (`status: decided | open | in-progress | done`). Do not copy and paste status paragraphs into other notes.
2. **ADR Claim-By-File:**
   An ADR number is claimed only when a file `docs/adr/00XX-<slug>.md` is committed.
3. **No Loss of Memory:**
   Historical rounds, specs, and mathematical derivations are preserved in `Specs/` and referenced from task threads.
4. **Code-First Acceptance:**
   Criteria must be runnable by a 3rd party (Foundry invariant tests, TypeScript parity harnesses, or ABI checkers).

---

Up: [[00 Dashboard - Project Command Center]] · Related: [[Researcher Agent]], [[Coder Agent]], [[Debugger Agent]]
