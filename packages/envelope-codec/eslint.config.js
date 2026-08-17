/**
 * ESLint configuration for @rwa-vault/envelope-codec (M2 — Canonical PQEnvelope byte layout).
 *
 * Re-exports the shared config from packages/config. The no-explicit-any and strict
 * equality rules are CRITICAL here: the envelope must serialise byte-identically
 * whether it runs in the NestJS backend or the WASM signer. A type slip in this
 * package is a signature-verification failure.
 */
import base from "@rwa-vault/config/eslint";

export default base;
