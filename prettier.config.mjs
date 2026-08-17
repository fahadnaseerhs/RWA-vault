/**
 * Root Prettier configuration — re-exports the shared config from packages/config.
 *
 * This file exists so that running `pnpm format` or `pnpm format:check` from
 * the repo root picks up the same settings that every workspace package uses.
 * The shared config lives in packages/config/prettier.config.js; this file is
 * just a one-line re-export to avoid duplication.
 *
 * Why not put the config directly here? Because packages/config/ is the single
 * source of truth for ALL shared tooling config (ESLint, Prettier, TypeScript).
 * If the Prettier settings lived in the root and the ESLint settings lived in
 * packages/config/, developers would have to look in two places. One place is
 * better than two.
 */
export { default } from "./packages/config/prettier.config.js";
