# ADR 0010 — Benchmark reference environments and measurement protocol

- **Status:** Proposed
- **Date:** 2026-08-20
- **Deciders:** Fahad Naseer, Hassan Attique, Fawaz Asif

## Context

RQ1 asks what the primitives cost: key generation, signing and verification latency,
and public-key and signature sizes, for all six primitives, native and in browser
WASM, on desktop and mid-range Android. §5.6 requires median and p95 with iteration
counts, size figures, and enough recorded metadata to reproduce a run. §7 is blunt
about the stakes: results without this metadata are not comparable.

The trap in a student benchmark is that the numbers are produced on whichever laptop
was free, six months apart, one in a debug build, and then tabulated together. §8.3
already forbids comparing debug numbers with release acceptance results. What is
missing is a named environment set, fixed before the first measurement, so that a
number taken in Sprint 2 and a number taken in Sprint 12 mean the same thing.

There is also a tension between two kinds of reference machine. A team workstation is
representative of real use but cannot be re-run by an examiner. A CI runner is
reproducible by anyone but is a shared virtualised host with noisy neighbours. The
project needs both, for different purposes, and needs to say which is which.

Sizes are a special case: public-key, private-key and signature sizes are constants
of the parameter set (ADR 0006), not measurements. They are reported once from
`metadata()`, asserted against the ADR 0006 table, and are not re-measured per
environment.

## Decision

### Three named environments, fixed for the project

**D1 — reproducible desktop reference.** The GitHub-hosted `ubuntu-24.04` runner
used by the `pq-native` CI job. Its value is that anyone — supervisor, examiner,
future reader — can re-run the harness on the same class of machine from the same
commit. Every release measures D1, and D1 is the environment used for
regression detection between commits.

**D2 — representative desktop reference.** One team development workstation, fixed
for the project rather than chosen per run. Its value is that it is a real machine a
real operator would use for a custodian or oracle signer. D2 is measured at each
milestone gate, not per commit.

**A1 — mid-range Android reference.** One physical Android handset, fixed for the
project, meeting this profile: released within the preceding four years, a mid-tier
SoC of the Snapdragon 6-series or MediaTek Dimensity 700-series class or equivalent,
4–8 GB RAM, running Chrome for Android at a recorded version. Not a flagship — the
point of the figure is the phone an investor at PKR 1,000 scale actually owns. A1 is
measured at each milestone gate. Emulators are not permitted: WASM performance on an
emulated ARM device measures the host, not the phone.

D1 is the only environment in CI. D2 and A1 are run by hand and their reports are
committed.

### Environment identity is scanned, not typed

**The harness collects the spec block itself, on whatever machine runs it.** No
field of an environment is hand-entered, so there is nothing to mistype and no
report can disagree with the machine that produced it.

_Native scan (Rust):_ CPU model string, physical and logical core count, total RAM,
OS name and build, target triple, `rustc` version, and the resolved Cargo feature
set — from `/proc/cpuinfo`, `/proc/meminfo` and `uname` on Linux, and from WMI on
Windows.

_Browser scan (JS):_ `navigator.userAgentData.getHighEntropyValues()` for `model`,
`platform`, `platformVersion`, `architecture`, `bitness` and `fullVersionList`, plus
`navigator.hardwareConcurrency`, `navigator.deviceMemory`, `screen` dimensions and
`devicePixelRatio`. On Chrome for Android, `model` returns the handset's model
string, which is what identifies A1. High-entropy hints require a secure context, so
the harness page is served over HTTPS or from `localhost`; a plain-HTTP LAN address
silently returns only the low-entropy set, so the harness treats a missing `model`
on a mobile user agent as a hard error rather than as an unknown field.

**Registration on first run, drift detection thereafter.** Scanning answers _what
this machine is_. It does not answer _which reference this machine is_, and that
second question is the one cross-sprint comparability rests on. So:

1. The harness derives a stable `fingerprint`: a SHA-256 over the normalised spec
   fields that do not change between reboots — CPU model, core count, RAM bucket, OS
   major version, and for A1 the device model. Volatile fields (browser patch
   version, OS build number, free memory) are recorded in the report but excluded
   from the fingerprint, so a Chrome update does not orphan the reference.
2. `packages/pq-core/reports/benchmarks/environments.json` starts empty. The first
   run in a given slot writes `D2` or `A1` with its scanned spec, its fingerprint,
   and the commit and date of registration. That _is_ the registration; nobody
   nominates a machine separately.
3. Every later run recomputes the fingerprint and compares it against the registered
   one. A match proceeds normally. **A mismatch neither fails nor overwrites** — the
   harness writes the report with `"environment": "unregistered"` and
   `"comparable": false`, and prints the diff between the registered and scanned
   specs. An unregistered report is a valid measurement of a real machine; it is
   simply not admissible in a milestone trend or a threshold check.
4. Re-registering an occupied slot — swapping the D2 workstation, replacing the A1
   handset — invalidates comparison with every earlier figure in that slot, so it
   requires a superseding ADR and is never done by the harness on its own.
5. The A1 profile is checked at registration as far as it can be: the harness warns
   if `deviceMemory` reports more than 8 GB or `hardwareConcurrency` suggests a
   flagship. It warns rather than refuses, because `deviceMemory` is coarse — rounded
   and capped at 8 — and cannot by itself establish the SoC class. A human confirms
   the profile once, at registration, against the scanned model string.

### Measurement protocol

Fixed here so it is not re-invented per run:

- **Build:** release, optimised, `kat` feature absent (ADR 0007). Native uses
  `criterion`; the browser harness uses `performance.now()` around each operation.
- **Warm-up and iterations**, per operation per primitive:
  - Fast operations (Falcon, ML-DSA, ML-KEM keygen/sign/verify/encaps/decaps):
    100 warm-up, 1,000 measured.
  - SLH-DSA-SHA2-128s signing and key generation, which are orders of magnitude
    slower: 5 warm-up, 50 measured.
  - Falcon-512 key generation, likewise slow: 5 warm-up, 50 measured.
- **Reported statistics:** median, p95, minimum, maximum, and the iteration count.
  The count is reported alongside every statistic, so a p95 over 50 samples is never
  mistaken for a p95 over 1,000.
- **Test payload:** a fixed 256-byte message, standing in for the canonical envelope
  until M2 freezes its layout, at which point the real serialised envelope size is
  used and the change is noted in the report. The payload size is recorded in every
  report either way.
- **A1 procedure:** device on mains power, battery above 50%, airplane mode on,
  screen on at fixed brightness, no other apps running, three independent runs of the
  full suite with the median run reported and the spread across runs stated. Thermal
  throttling is the dominant source of error on a mid-range handset, and a single run
  hides it.
- **Also recorded per run:** WASM package size (raw and gzipped), WASM module
  instantiation time, and peak JS heap during a signing loop — §5.3's memory-behaviour
  requirement and §5.6's artefact-size requirement.

### Acceptance thresholds

Set now so the report has something to conclude against rather than a table of
numbers:

- Falcon-512 sign on **A1** must complete in **under 500 ms at p95**. This is the
  one figure with a user-experience consequence: it sits inside every investor
  action, and RQ2's hypothesis is that network and block confirmation dominate
  perceived latency. If Falcon signing on a mid-range phone breaches this, that
  hypothesis is false and the finding is a result, not a failure.
- WASM package, gzipped, **under 2 MB** for the conformance build. If breached, the
  Falcon-only browser build contemplated in ADR 0004 is triggered.
- Any operation regressing **more than 25%** on D1 between two commits fails the
  benchmark smoke check in the release gate.

A breached threshold is a finding to publish and explain, not a number to re-run
until it passes. Re-running a benchmark to obtain a better figure without changing
the code is prohibited; if a run is discarded, the reason is recorded.

## Consequences

**Good.** Every RQ1 figure is attributable to a named environment with recorded
metadata, so figures from different sprints are comparable and an examiner can
reproduce at least the D1 column.

**Good.** Separating D1 from D2 resolves the reproducibility-versus-realism tension
by keeping both and labelling which is which, instead of picking one machine and
hoping it satisfies both readers.

**Good.** Thresholds fixed before measurement mean the acceptance criteria cannot be
retrofitted to the results — which is the specific way benchmark sections in student
projects lose their value.

**Good.** Nothing in Stage 0 is waiting on a hardware answer. `environments.json`
self-populates on first contact with each machine, so measuring can begin as soon as
there is a build to measure, and the recorded spec is by construction the spec of
the machine that produced the numbers rather than someone's recollection of it.

**Good.** Registering on first run and then detecting drift keeps the property that
motivated naming the environments at all. A run on a spare laptop still produces
data; it is labelled `comparable: false` instead of quietly entering a trend line
alongside figures from a different CPU.

**Costly.** D2 and A1 are manual runs, so they happen at milestone gates rather than
continuously, and a regression on Android could go unnoticed for weeks. D1's
per-commit regression check is the compensating control; the two desktop
environments will move together for anything that is a real algorithmic regression.

**Costly.** Locking A1 to one handset for the project means the Android figure
describes one device, not a distribution. This is the honest scope of a three-person
project, and the report says so: the claim is "on this device", with the profile
stated so a reader can judge how far it generalises.

**Costly.** Portable-C-only builds (ADR 0003) mean these numbers are a lower bound on
achievable performance; an AVX2 build would be faster on D1 and D2. Every benchmark
report must repeat this so the figures are not read as the ceiling.

**Costly, and the important one: a spec scan sees hardware, not conditions.** It
cannot see thermal state, CPU governor, background load, battery level, or whether
another tab is busy — and on a mid-range handset those dominate the variance the
figures are trying to report. Auto-detection therefore does not replace any part of
the A1 procedure above: mains power, airplane mode, fixed brightness, nothing else
running, three independent runs with the spread stated. The scan records the machine;
the procedure controls the measurement, and the two are not substitutes.

**Costly.** The browser scan depends on client hints, which are coarse and defeatable.
`deviceMemory` is rounded and capped at 8 GB, so it cannot distinguish a 8 GB phone
from a 16 GB one; a privacy-hardened browser or a non-secure context can withhold
the high-entropy set entirely. Hence the hard error on a missing `model`, and hence
the human confirmation of the SoC class at registration rather than a purely
automatic profile check.

**Costly.** The fingerprint field selection is a judgement call with failure modes in
both directions: too strict and a RAM upgrade orphans D2 mid-project, too loose and
two similar team laptops collide into one slot. It is written down here so that
tuning it is a reviewed code change rather than a quiet adjustment, and any change to
the fingerprint definition re-registers every slot.

**Costly.** Fifty samples for SLH-DSA gives a noisier p95 than a thousand would.
Accepted: at that operation's cost, a thousand iterations would dominate the run.
The iteration count travels with the statistic precisely so the reader can discount
it.

## Alternatives considered

**Populate `environments.json` by hand before the first run.** Rejected: it makes the
recorded spec a transcription of the machine rather than a reading of it, so it can
drift from reality silently and can be mistyped in a field nobody re-checks. It also
blocks the first measurement on an administrative answer that the first measurement
would itself supply.

**Auto-scan with no registration — treat whatever machine ran as the reference.**
Rejected, and this is the failure the registration step exists to prevent. Detection
alone makes every run self-consistent and the series meaningless: a milestone-gate
figure from one workstation and the next from another are both correctly labelled and
silently incomparable, which is worse than a typo because nothing looks wrong.

**Fail the run when the fingerprint does not match a registered slot.** Rejected: it
discards a real measurement and makes an opportunistic run on a spare machine
impossible, which discourages measuring at exactly the moments extra data is cheap.
Recording the run as `comparable: false` keeps the data and the discipline at once.

**Use a CI runner as the only reference.** Rejected: a shared virtualised host with
unpredictable neighbours is a poor stand-in for a custodian's or an oracle's machine,
and RQ1 asks what the primitives cost in use, not in a container.

**Use a team laptop as the only reference.** Rejected: nothing in the thesis would be
reproducible by anyone who does not have that laptop, and the machine will be
retired long before the record it supports.

**Benchmark on an Android emulator or a cloud device farm.** The emulator is
rejected outright — it measures the host CPU. A device farm was considered and
rejected on cost and on the free tiers' inability to guarantee the same device
across runs, which defeats the purpose of a fixed reference.

**Use a flagship phone because it is what the team owns.** Rejected: it would produce
a comfortable number describing a device the target user does not have. The proposal
is explicit that the design targets PKR 1,000-scale participation, and a benchmark
that quietly assumes a flagship handset undermines that claim rather than supporting
it.

**Skip thresholds and report raw numbers.** Rejected: §5.6 requires the report to be
used to set UI latency expectations, API limits, record-size budgets and transaction
assumptions. A table with no threshold cannot fail, and a measurement that cannot
fail is not evidence.
