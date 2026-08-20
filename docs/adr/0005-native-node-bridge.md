# ADR 0005 — Native Node bridge: an N-API addon via napi-rs, plus a separate offline CLI

- **Status:** Proposed
- **Date:** 2026-08-20
- **Deciders:** Fahad Naseer, Hassan Attique, Fawaz Asif

## Context

M1 manual §5.4 requires us to "select and implement the Node/service bridge: N-API
addon, a narrowly scoped process boundary, or another architecture-approved
interface", and notes the current TypeScript wrapper does not define one. The
research topic in §7 asks for the comparison to be made against deployment
platforms, key isolation, operational complexity, and CI packaging.

The callers are the NestJS services: the oracle signing round attestations with
ML-DSA-44, custodian and administration signing with ML-DSA-65, and every service
verifying envelopes. Two properties of that workload shape the choice. First, the
volume is real but modest — the anchoring argument assumes on the order of tens of
authenticated events per 60-second epoch, so this is not a throughput problem.
Second, verification is on the request path of a stateless verification service, so
per-call overhead shows up in RQ2's p50/p95 latency figures.

The root-of-trust role is different in kind. SLH-DSA-SHA2-128s signing happens in an
offline key-ceremony environment a few times a year. It has no Node service around
it, no concurrency, and no latency budget, and by design the machine that holds that
key runs as little software as possible.

Node is pinned at 22.16.0 by `.nvmrc`. Node-API is ABI-stable across Node major
versions, which matters because the alternative — V8-ABI addons — must be rebuilt
for every Node release.

## Decision

**Two bridges, because there are two workloads.**

**1. Services use an N-API addon built with napi-rs.** `napi` 3.12.1 (MIT) plus
`@napi-rs/cli`, targeting Node-API version 8, so the compiled addon loads on Node 18
and later without a rebuild per Node minor. The addon is a thin `#[napi]` wrapper
over the same Rust core the WASM build uses; it contains no cryptographic logic of
its own.

Its shape is fixed here:

- Every exported function is pure and stateless: it takes `Buffer`/`Uint8Array`
  inputs and returns owned buffers. There is no global mutable state, no key handle
  registry, and no session object, so concurrent calls from the libuv pool cannot
  interfere. This is how §5.4's "safe under concurrent service use" is met — by
  having no shared state to protect rather than by locking.
- Every operation is exposed in an async variant that runs on the libuv threadpool
  via napi-rs `AsyncTask`. SLH-DSA signing is slow enough to block the event loop
  visibly and must use it; ML-DSA and Falcon operations are fast enough for the sync
  variant, which is retained for use inside scripts and tests. The default export
  used by services is the async one.
- Errors cross the boundary as a `PqError` enum mapped to a JS `Error` carrying a
  stable machine-readable `code` (ADR 0006's error classes) and a fixed message
  string. Error payloads never include key bytes, signature bytes, message bytes, or
  lengths of secret material. This is enforced by the type: the Rust error enum's
  variants carry no byte-bearing fields, so a leak requires changing the type and
  therefore passing review.
- Prebuilt binaries are produced in CI for `x86_64-unknown-linux-gnu` and
  `x86_64-pc-windows-msvc` (ADR 0008) and published as artefacts with the addon, so
  neither a developer checkout nor a container build needs a Rust toolchain to run
  the services.

**2. The offline root role uses a standalone CLI binary, `pqctl`, not the Node
bridge.** A release-mode Rust binary over the same core, invoked by hand in the key
ceremony, reading and writing files. It is never linked into a service, never
published to npm, and never installed on a host that has network access. The Node
addon is compiled without any SLH-DSA _signing_ entry point at all; services get
SLH-DSA verification only, which is what they actually need — to check the root's
attestations. There is no code path by which a running service can be asked to sign
with the root key, because the code is not in the binary.

## Consequences

**Good.** No IPC, so private-key bytes and message bytes are never serialised across
a process boundary, never queued, and never written to a socket or pipe that could
be logged by an intermediary. In-process is the smaller attack surface here, which
is the opposite of the usual intuition and is worth stating plainly: a signer
subprocess isolates the key from the service's memory, but only by putting the key's
_use_ on a channel that now has to be secured.

**Good.** Node-API's ABI stability means the addon survives Node upgrades. Combined
with prebuilt binaries, the operational story for the services is `pnpm install` and
nothing else.

**Good.** Removing root signing from the service binary is a structural control
rather than a policy. §8.4's requirement to reject role/algorithm mismatches is
enforced at higher boundaries for the lattice keys, but for the highest-authority key
it is enforced by absence.

**Costly.** A native addon in the dependency graph means the services can no longer
be built or run on a platform we do not publish a prebuilt for. macOS and ARM are
therefore unsupported for services (ADR 0008), which is a real constraint on the
team's own machines if anyone develops on an Apple laptop. Mitigation: the dev
container (already in `.devcontainer/`) runs Linux, and the WASM build offers a
slower fallback path for local experimentation.

**Costly.** A crash in the addon — an out-of-bounds in the vendored C, a stack
overflow in SLH-DSA verification on a hostile input — takes down the Node process,
where a subprocess would have contained it. This is the strongest argument for the
rejected alternative. The controls are the exact-length checks of ADR 0006 applied
_before_ any buffer reaches the C, the negative and malformed-input test suites
required by §5.5, and the fact that a stateless verification service holding no
authority can be restarted without consequence.

**Costly.** Two build outputs and two release paths — an npm-published addon and a
hand-carried CLI. The release gate in §5.7 must tag them together with the same
source commit so a ceremony signature can be traced to a build.

**Deferred.** If a later module needs Tier-1 service keys held under a different OS
user, in a different container, or behind an HSM or KMS, that is the condition that
flips this decision to an isolated signer. It is written down so the trigger is
recognised rather than argued: **key custody moving out of the service's own trust
boundary is what justifies a process boundary, not throughput and not crash
isolation.** Such a change supersedes this ADR.

## Alternatives considered

**An isolated signer process with a narrow IPC protocol.** The serious contender,
and the one the manual lists first among the alternatives. It gives crash isolation
and lets the key live under a different OS user or in a separate container. Rejected
for M1 because its central benefit — isolating key custody from the service — does
not apply to the keys in question: ML-DSA-44 and ML-DSA-65 service keys _are_ the
service's own authority, so a signer process holding them is inside the same trust
boundary drawn on a different diagram. In exchange it adds a wire format, a
serialisation of secret material, a supervision and restart story, a second thing to
deploy, and per-call IPC latency in RQ2's measurements. Retained explicitly as the
successor design with the trigger condition stated above.

**Neon.** The other mature Rust-to-Node binding. Rejected on ecosystem grounds
rather than technical defect: napi-rs ships first-class cross-compilation and
prebuilt-binary CI for Windows and Linux out of the box, which is precisely the
§5.4 requirement to "publish platform support and build artifacts for every
CI/runtime platform", and it is the more actively released of the two.

**Run the WASM build inside Node instead of a native addon.** Genuinely attractive:
one artefact for both browser and server, no per-platform prebuilds, no native crash
risk in the Node process, and the platform-support question disappears. Rejected
because it takes the portable-C performance penalty (ADR 0003) and then adds the
WASM penalty on top, in the one place where verification latency is on a user-facing
request path and is being measured as RQ2; because the browser build's entropy comes
from Web Crypto rather than the OS CSPRNG the services should use (ADR 0007); and
because it would make the service and the browser share a failure mode instead of
providing independent implementations to cross-check. Worth revisiting only if the
addon's platform matrix becomes a genuine operational obstacle.

**Expose SLH-DSA signing through the Node addon and rely on configuration to keep it
unused.** Rejected: it makes the protection of the root key a deployment property
that must be re-verified on every host, rather than a build property that is true
everywhere the binary runs.
