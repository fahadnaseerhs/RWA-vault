/**
 * Shared Prettier configuration for the entire RWA-Vault monorepo.
 *
 * This is the SINGLE source of truth for code formatting. It is consumed two ways:
 *
 *   1. The root `prettier.config.mjs` re-exports this file, so running
 *      `pnpm format` or `pnpm format:check` from the repo root uses these settings.
 *
 *   2. Individual packages inherit it transitively — Prettier walks up the
 *      directory tree and finds the root config.
 *
 * WHY EACH OPTION:
 * - semi: true            → explicit semicolons prevent ASI-related surprises
 * - singleQuote: false    → double quotes are the JSX default and match JSON
 * - trailingComma: "all"  → cleaner git diffs (adding an item doesn't modify
 *                           the previous line) and works in ES2017+ which we target
 * - printWidth: 100       → wider than the 80-column default, reflecting modern
 *                           wide-screen monitors, but narrow enough for side-by-side
 *                           diffs in GitHub's PR review UI
 * - tabWidth: 2           → community standard for JS/TS projects
 * - endOfLine: "lf"       → LF everywhere, even on Windows. Prevents mixed line
 *                           endings when three developers are on different OSes.
 *                           Git's core.autocrlf should also be set to `input`.
 */
export default {
  semi: true,
  singleQuote: false,
  trailingComma: "all",
  printWidth: 100,
  tabWidth: 2,
  endOfLine: "lf",
};
