# ADR 0004 — Browser WASM target: `wasm32-unknown-unknown` with a freestanding C shim

- **Status:** Proposed
- **Date:** 2026-08-20
- **Deciders:** Fahad Naseer, Hassan Attique, Fawaz Asif

## Context

The investor PWA signs with Falcon-512 in the browser so the device private key
never reaches an RWA-Vault service. That requires a WebAssembly build of the same
Rust core the services use. `packages/pq-core/package.json` already declares
`build:wasm` as `wasm-pack build native --target web --out-dir ../pkg`, and
`rust-toolchain.toml` already installs `wasm32-unknown-unknown`.

ADR 0003 puts five of the six primitives in vendored C. That collides with the WASM
target in a way that is easy to miss until it blocks a sprint.

`wasm-pack` builds `wasm32-unknown-unknown`, which is the minimal WebAssembly
target: it imports nothing from the host and provides no libc. The rustc platform
documentation is explicit that `wasm32-unknown-unknown` does not easily support
interop with C/C++ code, and points at `wasm32-unknown-emscripten` for that. The
`pqcrypto` project's own `WASM.md` documents exactly one WebAssembly target,
`wasm32-wasi`, and requires a WASI SDK sysroot via `WASI_SDK_DIR`. Neither of those
is what `wasm-pack` produces, and `wasm-pack` has an open, unresolved request for
`wasm32-unknown-emscripten` support.

So the naive reading — "vendor C, run `wasm-pack`" — has no supported path, and the
three candidate paths each cost something different. This has to be settled before
Stage 1, because Stage 1's stated purpose is a one-algorithm vertical slice that
validates the build on native _and_ `wasm32`.

What makes the problem tractable is the specific C we vendored. PQClean's `clean`
implementations are deliberately portable, freestanding-friendly C99. Across the
five vendored schemes the libc surface is small: the `<stdint.h>`/`<stddef.h>` type
headers, which are header-only, and a handful of `<string.h>` functions —
`memcpy`, `memset`, `memmove`, `memcmp` — which LLVM emits or which are a dozen
lines to supply. The selected schemes size their working buffers through macros and
caller-supplied or stack storage rather than `malloc`. There is no file I/O, no
locale, no threads, no floating-point libm dependency in the integer `clean`
implementations.

## Decision

**The browser build targets `wasm32-unknown-unknown` via `wasm-pack`, and the
vendored C is compiled for that target as freestanding code against a minimal shim
we own.**

Concretely:

- `build.rs` compiles the vendored PQClean sources with the `cc` crate for both the
  native and the `wasm32-unknown-unknown` targets. For `wasm32-unknown-unknown` it
  configures `clang` with `--target=wasm32-unknown-unknown`, `-nostdlib`,
  `-ffreestanding`, and no host include paths, so nothing can silently pick up a
  system libc header.
- A single `native/src/wasm_shim.rs` provides, behind `#[cfg(target_arch = "wasm32")]`
  and `#[no_mangle]`, the `mem*` symbols the linker asks for. It contains no
  cryptographic logic and is covered by its own unit tests.
- `wasm-bindgen` provides the JS boundary as normal, so `build:wasm` keeps working
  as written and the generated package lands in `packages/pq-core/pkg`.
- All six primitives are built into the WASM package, not only Falcon-512, because
  ADR 0002's conformance and benchmark obligations run in both targets. Production
  browser code is expected to call Falcon signing and verification only; that is an
  M10 integration constraint, not a build-time exclusion.

**This is a Stage 1 exit criterion, with a pre-declared fallback.** The Stage 1
vertical slice is not "one algorithm works natively" but "one algorithm produces a
signature natively that verifies in the browser build, and vice versa". If the
freestanding link cannot be made to work within the Stage 1 timebox, we fall back to
**`wasm32-wasip1` plus a browser WASI shim** — building against the WASI SDK sysroot
as `pqcrypto`'s `WASM.md` documents, and instantiating in the browser through a
JS-side WASI implementation instead of `wasm-bindgen` glue. That fallback is
recorded here so the team does not re-litigate it under time pressure; taking it
requires only a note in the Stage 1 report, not a new ADR, because it changes the
build and not the byte contract.

`wasm-pack` is pinned in CI at an exact version, alongside the Rust 1.81.0 pin
already in `rust-toolchain.toml`. The generated `pkg/` directory is **not**
committed; it is produced by CI and published as a build artefact with the metadata
of ADR 0008, which keeps the repository free of generated binaries and makes the
package reproducible from source rather than trusted from a checkout.

The WASM package must fail closed on initialisation: if `crypto.getRandomValues` is
unavailable (ADR 0007) or the module fails to instantiate, `init()` rejects and no
partially usable API is exposed.

## Consequences

**Good.** One Rust core, one C source tree, one set of golden vectors, two targets.
The manual's primary control against native/WASM byte mismatch — "use one Rust core,
shared golden vectors, and bidirectional cross-runtime tests" — is preserved
literally rather than approximated by two implementations that happen to agree.

**Good.** `wasm-bindgen` means the TypeScript adapter passes `Uint8Array` in and out
with no string conversion of key material, which is what §5.3 requires. A WASI route
would have meant hand-written memory marshalling across the JS boundary — more code
in the exact place where secret buffers are copied.

**Good.** The existing `build:wasm` script, the `rust-toolchain.toml` target list,
and the `packages/pq-core/pkg` output path all stay as written. Nothing in the M0
baseline has to be revised.

**Costly.** We own a libc shim, however small, in the path of cryptographic code. A
wrong `memcpy` is a catastrophic and quiet failure. The controls are that the shim
is separately unit-tested, that the cross-runtime vector tests compare WASM output
against native output byte-for-byte for every algorithm and every vector, and that
the shim is reviewed as cryptographic code under the two-approval rule.

**Costly.** This is an unsupported build configuration, in the sense that neither
`pqcrypto` nor the rustc book endorses C interop on `wasm32-unknown-unknown`. If a
future PQClean patch or clang release breaks it, we debug a linker, not a library.
The `wasm32-wasip1` fallback bounds that risk.

**Costly.** Building all six primitives into the browser package makes it larger
than the Falcon-only package the PWA needs. ML-DSA, ML-KEM and SLH-DSA are dead
weight for the investor app. §5.6 already requires a package-size report; if the
size proves unacceptable for the mid-range Android profile, the answer is a Cargo
feature that produces a Falcon-only browser package for M10 while the full package
remains for conformance — deferred until the size report says whether it is needed.

**Requires a CI gate.** The WASM matrix in ADR 0008 must run the full cross-runtime
suite, not a smoke test. A WASM build that compiles but computes differently is the
failure this whole decision is arranged around.

## Alternatives considered

**`wasm32-wasip1` with a browser WASI shim.** The documented path, and the reason it
is the fallback rather than the rejection. Not chosen as primary because it drops
`wasm-bindgen`, requiring hand-written JS marshalling of key and signature buffers
exactly where secret-handling discipline matters most; because it adds a WASI
polyfill and the WASI SDK sysroot to every developer machine and to CI; and because
it diverges from the `wasm-pack --target web` build the repository already declares,
so `build:wasm` and the `pkg/` convention would both have to be rewritten.

**`wasm32-unknown-emscripten`.** The target designed for exactly this — Rust code
interoperating with C on the web. Rejected because `wasm-pack` does not support it;
the request is open and unresolved upstream. Adopting it means giving up `wasm-pack`
and `wasm-bindgen` together and hand-rolling the packaging, which is strictly more
work than the WASI fallback for the same loss.

**Pure-Rust implementations for the WASM build only, C for native.** Rejected, and
this is the most important rejection in the record. It makes the WASM build trivial
and it destroys the property M1 exists to establish. Two implementations of the same
algorithm in the two runtimes means cross-runtime tests are no longer verifying one
core against itself but two codebases against each other; any divergence found late
is a research problem rather than a build problem, and any divergence _not_ found is
an investor whose signature the service rejects. The manual names this as a top
risk and prescribes one Rust core; we follow it.

**Ship no browser build; sign on a service.** Rejected: it deletes the property that
motivates Falcon's selection in the first place — that the device key never leaves
the device — and moves Falcon's floating-point Gaussian-sampling side channel onto a
shared host holding many users' keys, which the proposal explicitly refuses.
