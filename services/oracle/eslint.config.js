/**
 * ESLint configuration for @rwa-vault/oracle (M5 — Price oracle aggregation service).
 *
 * Re-exports the shared config from packages/config. The eqeqeq rule matters here:
 * price comparisons use bigint, and loose equality (==) between bigint and number
 * is legal JS but almost always a bug in financial arithmetic.
 */
import base from "@rwa-vault/config/eslint";

export default base;
