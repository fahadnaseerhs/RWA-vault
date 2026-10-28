---
tags: [rwa-vault, process, git, github]
updated: 2026-10-04
---
# Git & GitHub Workflow 🐙

Reference guide for Git commands, commit standards, branch tracking, and GitHub workflow for the **RWA-Vault** repository.

---

## 1. Repository Setup & Remote Tracking

### Clone with Submodules
Foundry contract libraries live as git submodules in `contracts/lib/`:
```bash
# Initial clone (includes submodules)
git clone --recurse-submodules <repo-url>
cd rwa-vault

# If already cloned without submodules:
git submodule update --init --recursive
```

### Inspect Remotes & Tracking
```bash
# View configured remotes and URLs
git remote -v

# Show detailed remote tracking information
git remote show origin

# Prune stale tracking branches deleted on remote
git fetch -p
```

---

## 2. Branching & Upstream Tracking

This project uses **trunk-based development with short-lived feature/module branches** merging into `main`.

### Creating & Tracking Branches
```bash
# Create and switch to a new branch
git checkout -b codex/module-1
# Or using modern git:
git switch -c codex/module-1

# Push and set upstream tracking branch
git push -u origin codex/module-1

# Verify which local branches track which remote branches
git branch -vv

# Set tracking on an existing local branch
git branch --set-upstream-to=origin/codex/module-1 codex/module-1
```

### Branch Conventions
| Branch Pattern | Purpose | Example |
| --- | --- | --- |
| `main` | Production-ready trunk; protected; requires 2 reviews & CI pass | `main` |
| `codex/module-<N>` | Module development branches | `codex/module-1` |
| `feat/<topic>` | Feature slices | `feat/virtual-share-offset` |
| `fix/<issue>` | Targeted bug fixes | `fix/ci-pnpm-cache` |

---

## 3. Commit Conventions

We strictly follow [Conventional Commits](https://www.conventionalcommits.org/). Commit messages must be structured, informative, and scoped to the relevant module (`m0`–`m11` or specific package/component).

### Format
```text
<type>(<scope>): <short imperative description>

[optional body explaining context, rationale, and deliverables]

[optional footer(s) / reference to stage or issue]
```

### Allowed Types
| Type | Purpose | Example |
| --- | --- | --- |
| `feat` | New capability or stage milestone | `feat(pq-core): complete module 1 stage 3 — runtime adapters` |
| `fix` | Bug fix in code or CI | `fix(ci): resolve TS2307 by wiring TypeScript project references` |
| `docs` | Documentation or README update | `docs: surface module 1 stage 1 on front page` |
| `test` | Adding or updating tests | `test(m7): invariant — every liquidation strictly increases HF` |
| `chore` | Dependency, build, or tooling maintenance | `chore(m0): pin pnpm via corepack` |
| `style` | Formatting or lint cleanup (Prettier/ESLint) | `style(docs): format README with Prettier` |

### Scopes
- Modules: `m0`, `m1`, `m2`, ..., `m11`
- Subsystems: `pq-core`, `envelope-codec`, `risk-engine`, `oracle`, `ci`, `docs`

---

## 4. Everyday Commands (Status, Staging & Diffs)

### Status & Inspections
```bash
# Check working tree status
git status

# Compact status with branch info
git status -sb
```

### Staging & Unstaging
```bash
# Stage specific files
git add packages/pq-core/src/index.ts

# Stage all modified & new files (excluding ignored files)
git add .

# Unstage a file without losing modifications
git restore --staged <file>

# Discard local changes to a file
git restore <file>
```

### Diffs & History
```bash
# View unstaged changes
git diff

# View staged changes against HEAD
git diff --staged

# View summary of changes (files + lines modified)
git diff --stat

# Compact recent commit history with graph
git log --oneline --graph --decorate -10

# View details of the latest commit
git show HEAD
```

---

## 5. Syncing: Pull, Fetch & Push

### Fetching & Pulling
```bash
# Download remote objects without modifying working tree
git fetch origin

# Pull changes with rebase (recommended to keep linear history)
git pull --rebase origin <branch>

# Standard pull
git pull origin <branch>
```

### Pushing
```bash
# First push of a new branch (sets tracking)
git push -u origin <branch-name>

# Subsequent pushes once upstream is set
git push

# Push tags
git push --tags
```

---

## 6. Pre-Push Verification Checklist

Before pushing any PR or stage commit to GitHub, ensure all quality gates pass locally:

```bash
# 1. Clean monorepo gate
pnpm install
pnpm lint
pnpm typecheck
pnpm build
pnpm test

# 2. Rust crypto crate gate (when touching pq-core)
cargo test --manifest-path packages/pq-core/native/Cargo.toml

# 3. Smart contract test gate (when touching contracts)
pnpm contracts:test
pnpm contracts:fmt
```

---

## 7. Useful Recovery & Maintenance Commands

### Stashing
```bash
# Save uncommitted work temporarily
git stash push -m "wip: adapter refactor"

# List stashes
git stash list

# Apply and remove latest stash
git stash pop
```

### Undo & Reset
```bash
# Amend the last commit message or add staged files
git commit --amend

# Soft reset (keeps changes staged)
git reset --soft HEAD~1

# Mixed reset (default, keeps changes in working directory)
git reset HEAD~1
```

---

Related: [[Working Conventions]] · [[Project Memory]] · [[Changelog]]
