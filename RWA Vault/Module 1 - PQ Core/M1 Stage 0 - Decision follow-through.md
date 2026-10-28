---
tags: [rwa-vault, m1, stage]
stage: 0
status: done
---
# M1 Stage 0 — Decision follow-through ✅

**Goal:** make the code changes that the ADRs (0002–0011) require. All three tasks are small and block Stage 1.

**Status: 3 / 3 done**

- [x] **S0-01** Split the algorithm union in `src/index.ts` into `PqSignatureAlgorithm` (4) + `PqKemAlgorithm` (2); add `ml-kem-768` and `ml-kem-1024`
  - Done when: `pnpm typecheck` is green and an exhaustive `switch` compiles with no `default` arm
- [x] **S0-02** Retarget `envelope-codec`: `PqEnvelope.algorithm` becomes `PqSignatureAlgorithm`, since an envelope is never signed by a KEM
  - Done when: assigning `"ml-kem-768"` is a type error
- [x] **S0-03** Set `evm_version` explicitly in `contracts/foundry.toml` (ADR 0008). It is set to `cancun`.
  - Done when: `forge build` succeeds and the value appears in `forge config`

Next: [[M1 Stage 1 - Crate skeleton and Falcon slice]] · Up: [[Module 1 - PQ Core]]
