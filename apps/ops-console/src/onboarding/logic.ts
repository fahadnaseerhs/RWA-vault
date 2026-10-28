/**
 * Pure onboarding decisions, identical to `OnboardAsset.s.sol` (T6.1b point 5): the
 * state branch, the clause 2-4 pre-check, the mint pre-flight and the revert sentences.
 * Every function takes a fresh chain snapshot, so the page never decides from stale
 * component state (T6 spec §4.2).
 */
import {
  ASSET_FROZEN_SENTENCE,
  MINT_REFUSED_SENTENCE,
  assetRegistryAbi,
  durationText,
  reserveTooLowSentence,
  sourceHoldsNewerSentence,
  staleSequenceSentence,
  valuationInFutureSentence,
  valuationStaleSentence,
  type FixtureAttestation,
} from "@rwa-vault/types";
import { encodeFunctionData, type Address, type Hex } from "viem";

export const AssetState = { UNREGISTERED: 0, PENDING: 1, LIVE: 2, FROZEN: 3 } as const;
export type AssetStateValue = (typeof AssetState)[keyof typeof AssetState];
export const STATE_NAMES = ["UNREGISTERED", "PENDING", "LIVE", "FROZEN"] as const;

/** What the chain says about one asset, read in one go. */
export interface AssetSnapshot {
  readonly state: AssetStateValue;
  readonly tokenOf: Address;
  /** Asset bound to the deployment's token, or zero. */
  readonly assetOfToken: Hex;
  readonly totalSupply: bigint;
  readonly reserve: bigint;
  readonly lastSeq: bigint;
  readonly valuationTs: bigint;
  readonly window: bigint;
  readonly sourceSeq: bigint;
  readonly sourceEnvelopeHash: Hex;
  readonly metadataHash: Hex;
  /** Latest block timestamp. */
  readonly now: bigint;
}

export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000" as const;
export const ZERO_HASH = `0x${"0".repeat(64)}` as Hex;

export type Branch =
  | { readonly kind: "register" }
  | { readonly kind: "admit" }
  | { readonly kind: "mint" }
  | { readonly kind: "already-live" }
  | { readonly kind: "refuse"; readonly sentence: string };

/** T6.1a §3 S. */
export function stateBranch(s: AssetSnapshot, intendedSupply: bigint): Branch {
  switch (s.state) {
    case AssetState.UNREGISTERED:
      return { kind: "register" };
    case AssetState.PENDING:
      return { kind: "admit" };
    case AssetState.FROZEN:
      return { kind: "refuse", sentence: ASSET_FROZEN_SENTENCE };
    default:
      if (s.totalSupply === intendedSupply) return { kind: "already-live" };
      if (s.totalSupply === 0n) return { kind: "mint" };
      return {
        kind: "refuse",
        sentence: `This asset already has a supply of ${s.totalSupply}, not ${intendedSupply}; a human must decide.`,
      };
  }
}

/** True when the asset is bound to `token`; an Error sentence when bound elsewhere. */
export function bindingStatus(
  s: AssetSnapshot,
  assetId: Hex,
  token: Address,
): "bound" | "unbound" | string {
  if (s.tokenOf.toLowerCase() === token.toLowerCase()) return "bound";
  if (s.tokenOf !== ZERO_ADDRESS) return "This asset is already bound to a different token.";
  if (s.assetOfToken !== ZERO_HASH && s.assetOfToken !== assetId) {
    return "This token is already bound to a different asset. Each lot needs its own token deployment.";
  }
  return "unbound";
}

/** The `setTokenFor` call for the owner multisig (no owner key in the browser). */
export function bindCalldata(assetId: Hex, token: Address): Hex {
  return encodeFunctionData({
    abi: assetRegistryAbi,
    functionName: "setTokenFor",
    args: [assetId, token],
  });
}

export interface ClauseCheck {
  readonly clause: 1 | 2 | 3 | 4;
  readonly label: string;
  readonly ok: boolean;
  readonly sentence?: string;
}

/** Clauses 2-4 evaluated client-side before admit (T6 spec §4.2 step 3). */
export function admitClauses(
  att: FixtureAttestation,
  s: AssetSnapshot,
  intendedSupply: bigint,
): ClauseCheck[] {
  const seq = BigInt(att.seq);
  const reserve = BigInt(att.reserve);
  const ts = BigInt(att.valuationTs);
  let seqSentence: string | undefined;
  if (seq <= s.lastSeq) seqSentence = staleSequenceSentence(seq, s.lastSeq);
  else if (s.sourceSeq > seq) {
    seqSentence = `${staleSequenceSentence(seq, s.sourceSeq)} ${sourceHoldsNewerSentence(s.sourceSeq)}`;
  }
  let fresh: string | undefined;
  if (ts > s.now) fresh = valuationInFutureSentence(ts, s.now);
  else if (s.window === 0n || s.now - ts > s.window)
    fresh = valuationStaleSentence(ts, s.window, s.now);
  return [
    {
      clause: 2,
      label: "Sequence is newer than the last accepted",
      ok: !seqSentence,
      sentence: seqSentence,
    },
    {
      clause: 3,
      label: "Attested reserve covers the supply to mint",
      ok: reserve >= intendedSupply,
      sentence:
        reserve >= intendedSupply ? undefined : reserveTooLowSentence(reserve, intendedSupply),
    },
    {
      clause: 4,
      label: `Valuation is fresh (within ${durationText(s.window)})`,
      ok: !fresh,
      sentence: fresh,
    },
  ];
}

/** Seconds left before the envelope goes stale; negative once it has. */
export function freshnessLeft(att: FixtureAttestation, s: AssetSnapshot): bigint {
  return BigInt(att.valuationTs) + s.window - s.now;
}

/** The mint pre-flight (AC-21): the failing condition, or undefined when it may be sent. */
export function mintPreflight(s: AssetSnapshot, intendedSupply: bigint): string | undefined {
  if (s.state !== AssetState.LIVE) return "the asset is not LIVE";
  if (s.window === 0n || s.valuationTs > s.now || s.now - s.valuationTs > s.window) {
    return `the admitted valuation is not fresh (window ${durationText(s.window)}); submit a fresh attestation`;
  }
  if (s.totalSupply > s.reserve || intendedSupply > s.reserve - s.totalSupply) {
    return `totalSupply + intendedSupply (${s.totalSupply} + ${intendedSupply}) exceeds the reserve (${s.reserve})`;
  }
  return undefined;
}

/** A revert as viem decodes it against the M3 ABIs. */
export interface DecodedRevert {
  readonly errorName: string;
  readonly args?: readonly unknown[];
}

/**
 * Turns a revert into the sentence shown on the page. Never returns hex or a selector
 * (AC-13): an unknown error gets a plain request to report it.
 */
export function describeRevert(err: DecodedRevert | undefined, now: bigint): string {
  const n = (i: number): bigint => BigInt(err?.args?.[i] as bigint);
  switch (err?.errorName) {
    case "StaleSequence":
      return staleSequenceSentence(n(0), n(1));
    case "ReserveTooLow":
      return reserveTooLowSentence(n(0), n(1));
    case "ValuationStale":
      return valuationStaleSentence(n(0), n(1), now);
    case "ValuationInFuture":
      return valuationInFutureSentence(n(0), n(1));
    case "TransferNotCompliant":
      return MINT_REFUSED_SENTENCE;
    case "ReceiverNotVerified":
      return "The provider wallet is not KYC-verified, so it cannot receive the mint.";
    case "AssetNotLive":
      return "The asset is not LIVE.";
    case "NotAuthorisedAgent":
    case "NotAuthorisedSubmitter":
      return "The connected key is not an authorised agent for this deployment.";
    case undefined:
      return "The chain refused this step for an unexpected reason. Report it.";
    default:
      return `The chain refused this step (${err?.errorName}). Report it if it persists.`;
  }
}
