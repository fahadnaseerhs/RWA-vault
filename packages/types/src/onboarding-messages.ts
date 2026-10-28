/**
 * @module @rwa-vault/types/onboarding-messages
 * @description The operator-facing sentences of provider onboarding (T6 spec §3.4,
 * T6.1a spec §3), shared by `scripts/onboard` and the ops-console page (T6.1b point 6) so
 * the two can never word a failure differently.
 *
 * `contracts/script/OnboardAsset.s.sol` cannot import TypeScript, so its
 * `describeAdmitError` is held to the same text by the vectors in
 * `packages/types/fixtures/onboarding-sentences.json`: the TS test and the forge test
 * `test_SentenceVectorsMatchShared` both assert every vector.
 */

/** Clause 1 failed (raised off-chain only, ADR 0027). */
export const BAD_ATTESTATION_SIG_SENTENCE =
  "The custodian's signature on this attestation is not valid for the registered custodian key.";

/** Appended to both timestamp sentences (AC-19). */
export const ENVELOPE_TIMESTAMP_NOTE =
  "This is the timestamp inside the signed envelope; editing the input file will not change it.";

/** The non-dismissible ADR 0017 banner on the attestation step (AC-12). */
export const MS1_RESERVE_BANNER =
  "MS1: reserve is asserted by the custodian, not independently verified";

/** Printed on every receipt of a FIXTURE lot (ADR 0017). */
export const FIXTURE_RECEIPT_LINE = "MS1 FIXTURE ATTESTATION — NOT INDEPENDENTLY VERIFIED";

export const ASSET_FROZEN_SENTENCE = "This asset is frozen; an operator must resolve it.";

export const WAITING_FOR_OWNER_SENTENCE =
  "Waiting for the owner multisig to bind the token. Re-run this command after it confirms.";

export const MINT_REFUSED_SENTENCE =
  "Compliance refused the mint; the pre-flight passed, so the state changed between the check and the send. Re-run.";

type Num = bigint | number;

/** "24 hours" when whole hours, else "N seconds" (matches OnboardAsset._duration). */
export function durationText(seconds: Num): string {
  const s = BigInt(seconds);
  return s !== 0n && s % 3600n === 0n ? `${s / 3600n} hours` : `${s} seconds`;
}

export function staleSequenceSentence(seq: Num, last: Num): string {
  return `This attestation (seq ${seq}) is older than or equal to the last one accepted (seq ${last}).`;
}

/** Added after {@link staleSequenceSentence} when it is the attestation source that holds seq `m`. */
export function sourceHoldsNewerSentence(m: Num): string {
  return `The source already holds a newer attestation (seq ${m}).`;
}

export function reserveTooLowSentence(reserve: Num, intendedSupply: Num): string {
  return `The attested reserve (${reserve}) is less than the supply you asked to mint (${intendedSupply}).`;
}

/** @param now chain time in Unix seconds */
export function valuationStaleSentence(valuationTs: Num, window: Num, now: Num): string {
  const ts = BigInt(valuationTs);
  const n = BigInt(now);
  const ageHours = n > ts ? (n - ts) / 3600n : 0n;
  return `This valuation is ${ageHours} hours old; the limit is ${durationText(window)}. ${ENVELOPE_TIMESTAMP_NOTE}`;
}

export function valuationInFutureSentence(valuationTs: Num, now: Num): string {
  const ts = BigInt(valuationTs);
  const n = BigInt(now);
  return (
    `This valuation is dated ${ts - n} seconds in the future ` +
    `(envelope valuationTs ${ts}, chain time ${n}). ${ENVELOPE_TIMESTAMP_NOTE}`
  );
}

/** Only for the script's log; the page never shows hex (AC-13). */
export function unexpectedAdmitErrorSentence(revertData: string): string {
  return `Admission reverted with ${revertData}; unexpected; report it.`;
}

export function providerNotVerifiedSentence(wallet: string): string {
  return `The provider wallet ${wallet} is not KYC-verified. Run VerifyWallet first (How to Run §6).`;
}
