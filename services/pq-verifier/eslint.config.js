/**
 * ESLint configuration for @rwa-vault/pq-verifier (M2 — Envelope verification service).
 *
 * Re-exports the shared config from packages/config. The no-explicit-any rule is
 * especially critical here: the verifier must validate envelope fields against exact
 * types — an `any` in this path silently skips a check.
 */
import base from "@rwa-vault/config/eslint";

export default base;
