---
type: standard
tags: [rwa-vault, standard, locked]
status: locked
updated: 2026-10-27
---
# 🔒 Vault Standard — where everything goes, and in what shape

> **Locked.** This note and every `Template - *` note in `_Templates/` are the only allowed shapes for new notes.
> Change them only by a decision note (`type: decision`) that Fahad has decided. Agents never edit them on their own.
> Insert a template in Obsidian with **Ctrl/Cmd + P → "Templates: Insert template"** (folder is set to `_Templates`).

## 1. The four kinds of record, and their one home each

| Record | Template | Lives in | File name |
|---|---|---|---|
| **Decision** (a question Fahad must answer, then its answer) | [[Template - Decision]] | `Module N - <Name>/Questions/` (module) or `Project Memory/Decisions/` (cross-cutting) | `Q<NN> - <question in plain words>.md` · cross-cutting `C<NN> - …` |
| **Task** (a group of subtasks with acceptance criteria) | [[Template - Task]] | `Module N - <Name>/Tasks/` | `T<n> - <name>.md` |
| **Agent thread** (all Researcher ↔ Coder ↔ Debugger talk for one task) | [[Template - Agent Thread]] + [[Template - Thread Entry]] | `Module N - <Name>/Threads/` | `Thread - T<n.m> <name>.md` |
| **Concept note** (what a module is and why, plain words → technical) | [[Template - Module Concept]] | `Module N - <Name>/Understanding/` | `NN - <topic>.md`, `00 - What is Module N` first, `99 - What's Been Built` last |

Long agent hand-off documents (debugger briefs, question rounds, answer rounds) go in `Threads/Rounds/` and are linked
from a thread entry: the thread stays the log, the round note holds the detail. Supporting records: deep specs in `Specs/`
(one copy only, never duplicated), maths and flows in
`Algorithms/`, commands in `Running/`, audits in `Project Memory/Audits/`. Superseded notes go to `_Archive/<date>_<reason>/`,
never deleted.

## 2. Module folder shape (every module, once its sprint starts)
```
Module N - <Name>/
├── 00 MN Dashboard.md        ← index only: links + tables, no status prose
├── Module N - <Name>.md      ← hub (Template - Module Hub)
├── Questions/                ← one Decision note per question
├── Tasks/                    ← one Task note per task group + "MN Task Board and Todo.md" (index)
├── Threads/                  ← one append-only Agent Thread per active task
│   └── Rounds/               ← long briefs and question/answer rounds, linked from thread entries
├── Specs/  Algorithms/  Understanding/  Running/
└── Decisions/
    ├── Open Questions for Fahad.md  ← index of Questions/ with status: open
    └── Decisions Log.md             ← index of Questions/ with status: decided (date · decision · ADR)
```
Modules not yet started stay as one note in `Modules/`. Do not pre-build empty folders.

## 3. Single source of truth (the anti-drift rules)
1. **Status lives in frontmatter only.** Dashboards, boards, logs and AGENTS.md *link* to notes; they never restate status
   in prose. If two places disagree, the note's frontmatter wins, and the other place is wrong.
2. **Precedence when sources disagree:** code on disk → ADR (`docs/adr/`) → note frontmatter → everything else.
3. **Every decided question with a non-obvious answer has an ADR.** `adr:` in frontmatter is a number that exists on disk,
   or `none` with a reason. Never "needs an ADR" for more than one working day — open a Task for it instead.
4. **ADR numbers are claimed by file** (`docs/adr/00NN-<slug>.md`, `Status: Proposed`). Statuses are only
   `Proposed`, `Accepted`, `Superseded by ADR NNNN`, `Rejected` (ADR 0001).
5. **Threads are append-only.** Corrections are new entries that point at the old one; never rewrite history.
   Entry times are real times, and `On Disk Now` quotes a path that exists.
6. **A task is ✅ only after a Researcher `VERIFY ✅` entry** in its thread, against its acceptance criteria.
7. **One copy of every note.** If you need it in two places, link it.

## 4. Controlled vocabulary (frontmatter values)
- `type`: `decision` · `task` · `thread` · `concept` · `hub` · `dashboard` · `spec` · `audit` · `standard` · `template`
- Decision `status`: `open` → `decided` → (`superseded` | `reopened`) · or `deferred`
- Task `status`: `blocked` · `ready` · `in-progress` · `in-review` (awaiting Researcher VERIFY) · `done` · `deferred`
- Thread `status`: `active` · `closed`
- `agent`: `researcher` 🧭 · `coder` ⌨️ · `debugger` 🐞 · `fahad` 👤
- Dates: `YYYY-MM-DD`. Times in threads: `YYYY-MM-DD HH:MM PKT`.

## 5. Thread action types
`PLAN` (🧭 plan + acceptance criteria) · `HANDOFF` (⌨️ code + test output) · `REPORT` (🐞 findings) · `ASK` (anyone → 🧭)
· `RULING` (🧭 answers an ASK) · `DECISION-NEEDED` (🧭 → 👤, also creates a Decision note) · `VERIFY ✅` (🧭 closes the task)

Up: [[00 Dashboard - Project Command Center]] · Related: [[Agents/Protocol|Agents Protocol]], [[Decisions Register]]
