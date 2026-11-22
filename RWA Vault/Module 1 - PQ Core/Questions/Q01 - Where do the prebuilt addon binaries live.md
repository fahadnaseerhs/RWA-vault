---
type: decision
id: M1-Q01
module: M1
status: decided
raised_by: researcher
raised_on: 2026-11-22
blocks: []
recommendation: "D — skip prebuilds for MS1; Rust mandatory, with a documented setup step"
decision: "D — no prebuilt addon binaries for MS1. Installing Rust (with the C toolchain) is mandatory for every machine that runs the services; one documented setup step builds the addon. S3-05 is descoped from MS1. Revisit prebuilds at release. Consequence: the CI service test jobs compile Rust, which is slower."
decided_by: "Fahad Naseer"
decided_on: "2026-11-22"
adr: none
tags: [rwa-vault, decision, m1, task3]
updated: 2026-11-22
---
# Q01 — Where do the prebuilt addon binaries live, so a checkout without Rust can run the services?

**Why it matters (plain words):** the N-API addon has to be compiled for Linux and Windows. If every teammate has to
install Rust to get it, the services break for anyone who does not. Picking the storage place decides who can download
the binary, how long it stays available, and how much release machinery we have to build before MS1.

**Blocks:** S3-05 (prebuild CI) · **Does not block:** S3-10 (contract test runs on a local build), S4 and S5 (T4, T5 can proceed).

## Options
- **Option A — GitHub Actions artifact from each CI run.** CI uploads the Linux and Windows `.node` files; teammates
  download them from the run. *Cost:* ~0.5 day, no new infrastructure. *Risk:* artifacts expire after the retention
  period, and only repo members can download them.
- **Option B — attach to a GitHub Release on a version tag.** Versioned, stable URLs. *Cost:* ~1 day, needs a tag and
  release step in CI. *Risk:* no release process exists yet, so this adds a step to every tagged build.
- **Option C — npm platform sub-packages (the napi-rs default).** `pnpm install` picks the right binary by OS
  automatically. *Cost:* ~2 days plus publishing rights. *Risk:* publishing to npm is outward-facing and is hard to undo.

- **Option D — no prebuilds for MS1; Rust is mandatory (chosen).** Every machine that runs the services installs Rust
  and the C toolchain, then runs one documented build step (`build:addon`). A setup script checks the toolchain. Nothing
  is published. *Cost:* about an hour of docs and a check script. *Risk:* a fresh machine needs Rust, and the CI
  service test jobs compile the addon every run, which is slower.

## Recommendation
**Option D**, because all three of us already work from a shared repo on demo-day machines, so a prebuilt binary adds
CI work and publishing risk for no MS1 benefit. Revisit prebuilds before release.

## Decision
> **D, decided by Fahad Naseer on 2026-11-22.** No prebuilt binaries for MS1. Rust is mandatory. S3-05 is descoped
> from MS1 and revisited at release. No ADR written yet; if "Rust is mandatory" should be a permanent rule, write one.

Up: [[Decisions/Open Questions for Fahad]] · Related: [[Tasks/T3 - Runtime adapters]]
