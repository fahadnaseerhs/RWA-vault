---
tags: [rwa-vault, repo]
---
# Repo Layout

```
apps/        client, ops-console
contracts/   Foundry project (src, test, script)
packages/    config, envelope-codec, pq-core, types
services/    anchor-batcher, oracle, pq-verifier, risk-engine, settlement-rail
docs/        README.md index; deliverables/, manuals/, reports/, adr/, architecture/
eval/        Python evaluation harness
infra/       local dev network (Docker)
```

- Rust PQ crate: `packages/pq-core/native`
- ADRs: `docs/adr/`
- M1 task list: `docs/reports/M1-task-breakdown.md`
- Deliverables (proposal, defense deck): `docs/deliverables/` — current revision only
- Docs index and conventions: `docs/README.md`
- Git: work branches like `codex/module-1`, PRs into `main`

Related: [[Module 1 - PQ Core]]
