/**
 * Shared T6.0 test fixtures. One lot, used by the acceptance tests and the
 * JSON Schema parity harness, so both exercise exactly the same input.
 */
import type { OnboardingInput } from "../onboarding.js";

/**
 * The §3.2 example lot: a 1 kg kilobar at 999.9 fineness. Weight basis is FINE
 * grams on all three sides (ADR 0020): grossWeight 1000e18 × 9999 / 10000 =
 * intendedSupply 999.9e18. unitValue is a deliberately synthetic per-fine-gram
 * figure, labelled FIXTURE, not a market quote (T6 note §9.1).
 */
export const GOLD_LOT_001: OnboardingInput = {
  assetId: "gold-lot-001",
  description: "1kg kilobar, 999.9 fine, serial XAU-88213",
  grossWeight: "1000000000000000000000",
  fineness: 9999,
  valuationBasis: {
    source: "FIXTURE - synthetic, not a quote; per FINE gram",
    currency: "USD",
    unitValue: "130000000000000000000",
    valuationTs: 1761523200,
  },
  custodianId: "custodian-brinks-dxb",
  intendedSupply: "999900000000000000000",
  attestations: [{ path: "script/input/att.gold-lot-001.seq1.cbor", attestor: "custodian" }],
  providerWallet: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
  token: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
};

/** A fixed "now" (fixture valuationTs + 1 day), so the future-timestamp check never depends on the real clock. */
export const NOW = 1761609600;

/**
 * Golden vector for the canonical eight-field `metadataHash` of {@link GOLD_LOT_001}
 * (T6.1a spec §3). `OnboardAsset.metadataHash` (Solidity) and `scripts/onboard/lib.mjs`
 * (viem, as T6.1b will use) both assert this value, so the two recipes cannot drift.
 */
export const GOLD_LOT_001_METADATA_HASH =
  "0x3312ef458e5205556ed418ffeb43dd9693817294e633bbc2f9f861b6a6deedd7";
