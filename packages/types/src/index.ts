/**
 * @module @rwa-vault/types
 * @description Shared domain types for the RWA-Vault protocol.
 *
 * This package is the shared type vocabulary consumed by every app and service
 * in the monorepo. ABI-derived bindings (generated from Solidity contract ABIs)
 * will also live here, so that a contract change surfaces as a compile error in
 * every TypeScript consumer — not a runtime failure discovered in production.
 *
 * DEPENDENCY DIRECTION:
 *   packages/types ← apps/*, services/*    (consumed by everyone)
 *   packages/types → nothing               (depends on nothing)
 *
 * This package has zero runtime dependencies by design. It exports only type
 * definitions and string literal unions that are erased at compile time (except
 * for the value-level constants that downstream code needs at runtime).
 */

/**
 * Asset lifecycle state machine.
 *
 * State transitions are enforced on-chain in AssetRegistry.sol (M3):
 *
 *   UNREGISTERED → PENDING → LIVE → FROZEN
 *                     ↑                |
 *                     └────────────────┘ (unfreeze, governance only)
 *
 * - UNREGISTERED: default state, asset ID not yet registered.
 * - PENDING: metadata submitted, awaiting attestation and custodian verification.
 * - LIVE: fully attested, minting of RWA tokens is permitted (proposal §II.B).
 * - FROZEN: suspended by governance; no minting, redemption, or borrowing allowed.
 *
 * Only LIVE permits minting — this is a security invariant tested by the
 * invariant fuzzing suite in contracts/test/invariant/.
 */
export type AssetStatus = "UNREGISTERED" | "PENDING" | "LIVE" | "FROZEN";

/**
 * The four evaluated asset classes.
 *
 * Gold is the mandatory reference asset for the thesis — it is the asset used
 * in all controlled experiments (Experiments A–F in the proposal §VII) because
 * it has the most liquid spot markets and the tightest oracle spreads, which
 * isolates the variables under test from data-quality noise.
 *
 * The other three (TBILL, SUKUK, REIT) demonstrate the protocol's generality
 * across different valuation methodologies:
 * - TBILL: mark-to-market with daily NAV
 * - SUKUK: Shariah-compliant fixed-income, with profit-rate rather than yield
 * - REIT: appraisal-based with quarterly revaluation
 */
export type AssetType = "GOLD" | "TBILL" | "SUKUK" | "REIT";

/**
 * Health-factor bands driving the risk state machine (proposal Model 3).
 *
 * The health factor (HF) is defined as:
 *   HF = (collateral_value × liquidation_threshold) / outstanding_debt
 *
 * The bands and their thresholds (defined in services/risk-engine/src/index.ts):
 *
 * | Band            | HF Range       | Effect                                      |
 * |-----------------|----------------|---------------------------------------------|
 * | HEALTHY         | HF ≥ 1.15      | All operations permitted                    |
 * | BORROW_FROZEN   | 1.00 ≤ HF < 1.15 | New borrows blocked; repayment encouraged |
 * | BUFFER_BAND     | 0.95 ≤ HF < 1.00 | Reserve buffer absorbs; partial liquidation |
 * | LIQUIDATABLE    | 0.90 ≤ HF < 0.95 | Ordinary liquidation runs                  |
 * | FULL_CLOSURE    | HF < 0.90      | Full closure; residual bad debt socialised  |
 *
 * The risk engine (M6) proposes transitions; the on-chain contract (M7) re-derives
 * HF and reverts if the engine was wrong or stale. An engine outage delays
 * liquidations but cannot cause an incorrect one.
 */
export type HealthBand =
  | "HEALTHY"
  | "BORROW_FROZEN"
  | "BUFFER_BAND"
  | "LIQUIDATABLE"
  | "FULL_CLOSURE";
