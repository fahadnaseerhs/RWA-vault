/**
 * Contract addresses, from `contracts/deployments/<chainid>.json` as written by DeployM3
 * (T6.1b point 1). Bundled at build time and chosen by the connected chain id; nothing is
 * hardcoded.
 */
import type { Address } from "viem";

export interface Deployment {
  readonly chainId: number;
  readonly owner: Address;
  readonly agent: Address;
  readonly identityRegistry: Address;
  readonly assetRegistry: Address;
  readonly attestationSource: Address;
  readonly token: Address;
  readonly valuationWindow: number;
}

const files = import.meta.glob<Deployment>("../../../../contracts/deployments/*.json", {
  eager: true,
  import: "default",
});

export function deploymentFor(
  chainId: number,
  all: Record<string, Deployment> = files,
): Deployment | undefined {
  return Object.values(all).find((d) => d.chainId === chainId);
}
