/**
 * M6 Risk engine.
 *
 * The engine holds NO authority: a liquidation transaction re-derives HF on-chain and
 * reverts if the engine was wrong or stale. An engine outage therefore delays
 * liquidations but cannot cause an incorrect one.
 */

/** Origination bound: no borrow or unlock may leave a post-state HF below this. */
export const ORIGINATION_HF = 1.15;

/** Solvency point. Below this the position enters the reserve-buffer band. */
export const SOLVENCY_HF = 1.0;

/** Below this a breach can no longer be assumed transient; ordinary liquidation runs. */
export const LIQUIDATION_HF = 0.95;

/** Below this the close factor lifts to full closure and residual bad debt is socialised. */
export const FULL_CLOSURE_HF = 0.9;
