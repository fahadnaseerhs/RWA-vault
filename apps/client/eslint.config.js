/**
 * ESLint configuration for @rwa-vault/client (M10 — Investor PWA).
 *
 * Re-exports the shared config from packages/config. This ensures every
 * package in the monorepo is linted against the same ruleset. If you need
 * a package-specific override (e.g. allowing browser globals for React),
 * extend the base config here rather than replacing it:
 *
 *   import base from "@rwa-vault/config/eslint";
 *   export default [...base, { rules: { "no-console": "off" } }];
 */
import base from "@rwa-vault/config/eslint";

export default base;
