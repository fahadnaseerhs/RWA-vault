/**
 * M5 Oracle aggregation.
 *
 * The ORDER of these checks is the security property: applying the median after the
 * deviation test would let a single corrupted feed decide whether the aggregate is
 * accepted. A correct outcome reached at the wrong check counts as a failure in
 * Experiment C.
 */

export const PIPELINE_STAGES = [
  "drop-invalid-or-stale-sources",
  "quorum-at-least-three",
  "median",
  "deviation-against-30min-twap",
  "monotonic-round-and-timestamp",
] as const;

/** Deviation bound against the 30-minute TWAP. */
export const DEVIATION_THRESHOLD = 0.1;

/** Minimum contributing sources; a statistic over two points resists nothing. */
export const QUORUM_MIN = 3;
