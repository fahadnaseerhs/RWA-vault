/**
 * ESLint configuration for @rwa-vault/pq-core (M1 — Post-quantum crypto wrapper).
 *
 * Re-exports the shared config from packages/config. This package wraps
 * Rust/liboqs builds — the TS layer here is a typed facade, and strict
 * typing ensures the facade matches the Rust API surface exactly.
 */
import base from "@rwa-vault/config/eslint";

export default base;
