/**
 * Shared flat ESLint configuration for every TypeScript package in the workspace.
 *
 * This is the SINGLE source of truth for lint rules across the entire monorepo.
 * Individual packages do NOT define their own rules — they import and re-export
 * this config from their own `eslint.config.js`:
 *
 *   ```js
 *   import base from "@rwa-vault/config/eslint";
 *   export default base;
 *   ```
 *
 * This guarantees that the "two approvals to merge" rule from the proposal is
 * actually checking the same standard everywhere — three slightly different configs
 * that drift package by package is worse than no linting at all, because it creates
 * a false sense of consistency.
 *
 * ARCHITECTURE NOTES:
 * - Uses ESLint v9+ flat config format (eslint.config.js, not .eslintrc).
 * - eslint-config-prettier is applied LAST so that Prettier-conflicting rules
 *   (indentation, semicolons, trailing commas) are disabled — Prettier owns formatting,
 *   ESLint owns correctness.
 * - typescript-eslint's recommended ruleset enables type-aware rules when a
 *   tsconfig is available in the package.
 */
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import prettier from "eslint-config-prettier";

export default tseslint.config(
  {
    // Global ignore patterns. These directories contain generated or third-party
    // code that we don't own and shouldn't lint.
    ignores: [
      "**/dist/**", // TypeScript compilation output
      "**/node_modules/**", // Dependencies (obviously)
      "**/pkg/**", // wasm-pack output (pq-core browser build)
      "**/out/**", // Foundry compilation output
      "**/cache/**", // Foundry compilation cache
    ],
  },

  // ESLint's built-in recommended rules — catches common JS mistakes like
  // unreachable code, duplicate keys, and accidental global assignments.
  js.configs.recommended,

  // typescript-eslint's recommended rules — adds TS-specific checks on top
  // of the JS base: no-unused-vars (TS-aware), ban-types, no-var-requires, etc.
  ...tseslint.configs.recommended,

  {
    rules: {
      // ── Unused variables ────────────────────────────────────────────────
      // Error on unused variables, but allow a leading underscore to mark a
      // deliberate discard. This is common in destructuring:
      //   const { needed, _ignored } = someObject;
      // and in function signatures where the parameter is required by an
      // interface but not used in a specific implementation.
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],

      // ── No explicit any ────────────────────────────────────────────────
      // The envelope codec (M2) must produce IDENTICAL bytes in every runtime
      // (NestJS backend, WASM browser signer, Node CLI). An `any` type in
      // the envelope serialisation path is a signature-verification bug
      // waiting to happen — the TypeScript compiler can't catch a mistyped
      // field if the object is typed as `any`. This rule is an error, not a
      // warning, because the cost of a false positive (adding a type annotation)
      // is trivial compared to the cost of a false negative (a runtime
      // signature failure that only manifests under specific data).
      "@typescript-eslint/no-explicit-any": "error",

      // ── Strict equality ────────────────────────────────────────────────
      // Always use === and !== instead of == and !=. Loose equality's type
      // coercion rules are a footgun in any project, but especially one
      // where bigint comparisons are common (bigint == number is allowed
      // by JS but almost always a bug in financial code).
      eqeqeq: ["error", "always"],

      // ── Console usage ──────────────────────────────────────────────────
      // Warn on console.log (should be replaced with a proper logger before
      // merge), but allow console.warn and console.error for genuinely
      // exceptional situations. The warning level means CI won't fail but
      // the developer sees the reminder.
      "no-console": ["warn", { allow: ["warn", "error"] }],
    },
  },

  // Apply Prettier's rule-disabling config LAST. This turns off every ESLint
  // rule that would conflict with Prettier's formatting decisions (indentation,
  // quotes, semicolons, trailing commas, etc.). The separation of concerns:
  //   Prettier → how code looks (formatting)
  //   ESLint   → how code works (correctness, patterns)
  prettier,
);
