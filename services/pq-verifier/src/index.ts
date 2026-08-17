/**
 * M2 PQ verification service.
 *
 * Accepts an envelope only if all seven conditions hold. A failure is rejected at a
 * NAMED check - the adversarial suite asserts the name, not merely the rejection.
 */

export const SEVEN_CONDITIONS = [
  "algorithm-allow-listed-for-action",
  "signer-resolves-to-active-unrevoked-key",
  "domain-separator-matches",
  "clock-inside-validity-window",
  "nonce-equals-stored-plus-one",
  "signature-verifies-over-zeroed-envelope",
  "payload-hash-matches-executed-payload",
] as const;

export type VerificationFailure = (typeof SEVEN_CONDITIONS)[number];
