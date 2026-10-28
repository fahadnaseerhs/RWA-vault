/**
 * The registered custodian key (T6.1b point 3), with the same rule as
 * `scripts/onboard/lib.mjs`: the committed key in `contracts/script/input/`, or on anvil only
 * the devnet fixture key in `contracts/.onboard/` when it exists. Its keccak256 must equal
 * `custodianKeyHash`. The key is never taken from the envelope.
 */
import { keccak256, toHex } from "viem";

export const ANVIL_CHAIN_ID = 31337;

interface CustodianConfig {
  readonly custodianKeyHash: string;
}

const committedCfg = import.meta.glob<CustodianConfig>(
  "../../../../contracts/script/input/custodian.json",
  { eager: true, import: "default" },
);
const committedPub = import.meta.glob<string>(
  "../../../../contracts/script/input/custodian.mldsa65.pub",
  { eager: true, query: "?url", import: "default" },
);
const devnetCfg = import.meta.glob<CustodianConfig>(
  "../../../../contracts/.onboard/custodian.json",
  {
    eager: true,
    import: "default",
  },
);
const devnetPub = import.meta.glob<string>("../../../../contracts/.onboard/custodian.mldsa65.pub", {
  eager: true,
  query: "?url",
  import: "default",
});

export class CustodianKeyError extends Error {}

const only = <T>(r: Record<string, T>): T | undefined => Object.values(r)[0];

/** Fetches and checks the key that applies to `chainId`. */
export async function loadCustodianKey(chainId: number): Promise<Uint8Array> {
  const devnet = chainId === ANVIL_CHAIN_ID && only(devnetCfg) !== undefined;
  const cfg = devnet ? only(devnetCfg) : only(committedCfg);
  const url = devnet ? only(devnetPub) : only(committedPub);
  if (!cfg || !url)
    throw new CustodianKeyError("No registered custodian key is bundled with this console.");
  const pub = new Uint8Array(await (await fetch(url)).arrayBuffer());
  return checkCustodianKey(pub, cfg.custodianKeyHash);
}

export function checkCustodianKey(pub: Uint8Array, custodianKeyHash: string): Uint8Array {
  if (keccak256(toHex(pub)).toLowerCase() !== custodianKeyHash.toLowerCase()) {
    throw new CustodianKeyError(
      "The custodian key does not match custodianKeyHash in custodian.json.",
    );
  }
  return pub;
}
