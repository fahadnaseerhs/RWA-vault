---
tags: [rwa-vault, m1, stage]
stage: 7
status: not-started
---
# M1 Stage 7 — Release gate ⬜

**Goal:** a supply-chain-checked, tagged release of the library and all artefacts, with conformance, benchmark and gas reports attached.

**Status: 0 / 9**

- [ ] **S7-01** `deny.toml` + `cargo deny` in CI (licences + advisories)
- [ ] **S7-02** SBOM (CycloneDX + `pnpm licenses`)
- [ ] **S7-03** `metadata.json` + `SHA256SUMS` emitter (ADR 0008 fields)
- [ ] **S7-04** CI job `pq-artifacts` (tags only): addon prebuilts, WASM package, `pqctl`
- [ ] **S7-05** `kat`-absence assertion in the release job (hard failure)
- [ ] **S7-06** Weekly scheduled `cargo deny` / `pnpm audit`
- [ ] **S7-07** Path filters on the four M1 CI jobs
- [ ] **S7-08** `packages/pq-core/README.md` covers the six items in manual §9
- [ ] **S7-09** Tag the library and artefacts together at one commit, with all reports

Prev: [[M1 Stage 6 - ETHFALCON dispute verifier]] · Up: [[Module 1 - PQ Core]]
