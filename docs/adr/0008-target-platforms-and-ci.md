# ADR 0008 — Supported platforms and the M1 CI matrix

- **Status:** Proposed
- **Date:** 2026-08-20
- **Deciders:** Fahad Naseer, Hassan Attique, Fawaz Asif

## Context

§5.4 requires M1 to publish platform support and build artefacts for every
CI/runtime platform that will host an RWA-Vault signer or verifier, and §8.5
prescribes three CI matrices — native, WASM, Solidity — plus artefact metadata. The
existing pipeline in `.github/workflows/ci.yml` has three jobs (`node`, `contracts`,
`contracts-invariants`), all on `ubuntu-latest`, and knows nothing about Rust.

Three facts constrain the answer. ADR 0005 makes the services depend on a native
addon, so every platform we claim to support must have a prebuilt binary produced
and tested. ADR 0003 vendors C, so every platform needs a working C compiler in CI.
And the team develops on Windows 11 while the dev container and CI run Linux, so
both must be first-class or the "works on my machine" failures land on the
cryptographic code, which is the worst place for them.

Claiming a platform is not free: it is a build, a test run, an artefact, and a
support obligation for the life of the project. Claiming one we do not test is
worse than not claiming it.

## Decision

### Supported platforms

**Tier 1 — built, fully tested, artefacts published.** These are the only platforms
on which RWA-Vault services and tooling are supported.

| Target                     | Runner         | What runs there                                 |
| -------------------------- | -------------- | ----------------------------------------------- |
| `x86_64-unknown-linux-gnu` | `ubuntu-24.04` | services, `pqctl`, conformance, benchmarks      |
| `x86_64-pc-windows-msvc`   | `windows-2022` | local development, `pqctl` for the key ceremony |
| `wasm32-unknown-unknown`   | `ubuntu-24.04` | investor PWA signer, browser conformance        |

**Explicitly unsupported, and stated so in the package README:** macOS (any
architecture), `aarch64` Linux, 32-bit anything, Node below 18, and browsers without
`crypto.getRandomValues` or WebAssembly. We do not have the hardware to test macOS
or ARM, and an untested prebuilt is a claim we cannot stand behind. Developers on
unsupported machines use the dev container in `.devcontainer/`.

Node is pinned at 22.16.0 by `.nvmrc`; the addon targets Node-API version 8, so it
loads on Node 18+ without rebuilding (ADR 0005). Rust is pinned at 1.81.0 by
`rust-toolchain.toml`; `wasm-pack` and `@napi-rs/cli` are pinned at exact versions in
CI. Solidity is pinned at 0.8.26 with `optimizer = true, optimizer_runs = 200` by
`contracts/foundry.toml`.

**One gap in the existing configuration must be closed before any gas number is
published:** `foundry.toml` does not set `evm_version`, so the compiler's default for
0.8.26 applies silently and could change under a Foundry upgrade. §8.5 requires the
EVM target to be pinned. We set it explicitly to `cancun` and, as a Stage 6 gate,
verify that a contract compiled at that target deploys and executes on Arbitrum
Sepolia before the RQ3 report is published; if it does not, we drop to `shanghai`
and record the change in the report. Either way the value is stated alongside every
gas figure.

### CI jobs

Four jobs are added to `.github/workflows/ci.yml`, alongside the existing three.
They run only when `packages/pq-core/**`, `contracts/**` or the workflow itself
changes, so M1's build time does not tax unrelated pull requests.

**`pq-native`** — matrix over `ubuntu-24.04` and `windows-2022`:
`cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo build --release`,
`cargo test --release`, the vector suite of ADR 0009, and `cargo deny` for licences
and advisories. Both platforms are required checks.

**`pq-wasm`** — `ubuntu-24.04`: `wasm-pack build --target web`, the browser test
suite in headless Chromium, the full cross-runtime vector suite in both directions
for every primitive, `tsc --build` over the TypeScript adapters, and a package-size
report emitted as a job summary.

**`pq-conformance`** — `ubuntu-24.04`: the release-plus-`kat` build described in
ADR 0007, running the full ACVP and KAT inventory, producing the machine-readable
and human-readable reports of §5.5. **This job publishes reports only, never
binaries.**

**`pq-artifacts`** — runs on tags only. Builds without the `kat` feature, asserts
that feature is absent from the resolved feature set, and publishes the addon
prebuilts, the WASM package, and `pqctl` with the metadata below.

The `contracts` job gains the ETHFALCON shared-vector tests and a `forge snapshot`
gas check with an explicit regression threshold, per §8.5.

### Artefact metadata

Every published artefact carries a `metadata.json` and a `SHA256SUMS`. The metadata
records: source commit SHA; Rust toolchain version; `wasm-pack` / `@napi-rs/cli`
versions; target triple; the resolved Cargo feature set; the vendored PQClean
upstream commit SHA and the `slh-dsa` crate version; `solc` version, optimizer runs
and EVM version for the Solidity artefacts; the enabled algorithm list; and links to
the conformance, benchmark and gas reports for that commit. An SBOM
(CycloneDX, via `cargo cyclonedx` and `pnpm licenses`) is generated in the same job.

### Vulnerability ownership

`cargo deny` and `pnpm audit` run in CI on every pull request and on a weekly
schedule. Because PQClean is archived (ADR 0003) it will never issue an advisory of
its own; the compensating control is a named owner who checks the PQ Code Package
repositories and the pqc-forum list at each milestone gate, recording the check in
the milestone report even when the answer is "no change".

## Consequences

**Good.** Windows is a required check rather than a courtesy. The team's own
machines are covered by the same gate as the deployment target, so an MSVC-only
build break in the vendored C surfaces on the pull request that causes it.

**Good.** Splitting `pq-conformance` from `pq-artifacts` makes ADR 0007's guarantee
structural: the job that can build KAT hooks cannot publish, and the job that
publishes cannot build them.

**Good.** Path filtering keeps the M1 jobs off unrelated pull requests, which
matters because they are the slowest in the pipeline.

**Costly.** Seven CI jobs where there were three, two of them on a Windows runner,
which is the slowest and most expensive kind. Accepted: the alternative is
discovering a Windows C-compilation difference during the key ceremony.

**Costly.** Refusing macOS is a real constraint. If a team member is on an Apple
machine, they develop in the container and cannot run the native addon on the host.
Reversing this needs hardware, not a decision.

**Costly.** Pinning `evm_version` may change the gas numbers relative to any figure
measured before the pin. That is the point — an unpinned number is not
reproducible — but it means gas figures produced before Stage 6 are provisional and
must be labelled as such.

**Binding on the release gate.** §5.7's release gate is the `pq-artifacts` job plus
the reports from `pq-conformance`, `pq-wasm` and the benchmark run. A tag that does
not carry all four is not a release.

## Alternatives considered

**Linux only, and treat Windows as a developer convenience.** Rejected: `pqctl`
performs the offline root key ceremony, and the machine available to do that
air-gapped is a Windows laptop. An untested Windows build of the tool that signs the
root of trust is not acceptable, and the team develops on Windows daily, so the
break would be found by a person rather than by CI.

**Add `aarch64-unknown-linux-gnu` as a cross-compiled, untested target.** Rejected:
a prebuilt binary nobody executes is a support claim without evidence, and ARM is
where a portable-C build is most likely to differ. It can be added when there is a
deployment target that needs it and a runner that can test it.

**Use `ubuntu-latest` and `windows-latest` rather than dated images.** Rejected: the
whole point of the pinning discipline in §8.3 is that a green build last week and a
red build today should be traceable to a changelog. `latest` moves under us and
takes the C toolchain with it.

**Commit the generated `pkg/` WASM output so consumers need no Rust toolchain.**
Rejected: it puts a generated binary in the repository, makes the diff unreviewable,
and invites a `pkg/` that no longer matches `native/`. CI artefacts with checksums
and build metadata give consumers the same convenience with provenance attached.

**Run the full conformance suite on every pull request.** Rejected: the ACVP sets
are large and SLH-DSA signing is slow, so it would dominate the inner loop. It runs
on `main`, on tags, and on any pull request touching `packages/pq-core/**` — which
is every pull request that could break it.
