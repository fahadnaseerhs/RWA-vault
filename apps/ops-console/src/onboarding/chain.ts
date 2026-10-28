/**
 * The page's only contact with the chain: one snapshot reader and four writes (register,
 * submitAttestation, admit, mint). There is deliberately nothing else here (AC-14). The
 * owner's `setTokenFor` is shown as calldata for the multisig and never sent.
 */
import {
  assetRegistryAbi,
  custodianAttestationSourceAbi,
  identityRegistryAbi,
  tokenAbi,
} from "@rwa-vault/types";
import {
  BaseError,
  ContractFunctionRevertedError,
  createPublicClient,
  createWalletClient,
  custom,
  http,
  type Abi,
  type Account,
  type Address,
  type EIP1193Provider,
  type Hex,
  type PublicClient,
  type Transport,
  type WalletClient,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import type { Deployment } from "./deployments.js";
import { ANVIL_CHAIN_ID } from "./custodian.js";
import type { AssetSnapshot, AssetStateValue, DecodedRevert } from "./logic.js";

export interface AttestationArgs {
  readonly assetId: Hex;
  readonly reserve: bigint;
  readonly seq: bigint;
  readonly valuationTs: bigint;
}

export interface OnboardingChain {
  readonly chainId: number;
  readonly deployment: Deployment;
  readonly signer: Address;
  isVerified(wallet: Address): Promise<boolean>;
  snapshot(assetId: Hex): Promise<AssetSnapshot>;
  register(assetId: Hex, metadataHash: Hex, slug: string): Promise<Hex>;
  submitAttestation(att: AttestationArgs, envelopeHash: Hex): Promise<Hex>;
  admit(assetId: Hex, intendedSupply: bigint): Promise<Hex>;
  mint(to: Address, amount: bigint): Promise<Hex>;
}

/** A write the chain refused, decoded against the M3 ABIs. */
export class ChainRevert extends Error {
  constructor(readonly revert: DecodedRevert | undefined) {
    super(revert?.errorName ?? "reverted");
  }
}

export class SignerRefused extends Error {}

export type SignerChoice =
  | { readonly kind: "injected"; readonly provider: EIP1193Provider }
  | { readonly kind: "anvil-dev-key"; readonly rpcUrl: string; readonly privateKey: Hex };

/**
 * Connects with the operator's Tier 1 agent key (T6.1b point 4). The anvil dev key is
 * accepted on chain 31337 only, and never when it is the deployment's owner.
 */
export async function connect(
  choice: SignerChoice,
  deploymentFor: (chainId: number) => Deployment | undefined,
): Promise<OnboardingChain> {
  let transport: Transport;
  let account: Account | Address;
  if (choice.kind === "injected") {
    transport = custom(choice.provider);
    const [addr] = (await choice.provider.request({ method: "eth_requestAccounts" })) as Address[];
    if (!addr) throw new SignerRefused("The wallet returned no account.");
    account = addr;
  } else {
    transport = http(choice.rpcUrl);
    account = privateKeyToAccount(choice.privateKey);
  }
  const pub = createPublicClient({ transport });
  const chainId = await pub.getChainId();
  const deployment = deploymentFor(chainId);
  const signer = typeof account === "string" ? account : account.address;
  const problem = signerProblem(choice.kind, chainId, signer, deployment);
  if (problem || !deployment) throw new SignerRefused(problem);
  const wallet = createWalletClient({ account, transport });
  return viemChain(pub, wallet, chainId, deployment, signer);
}

/** Why a signer may not be used, or undefined when it may (T6.1b point 4). */
export function signerProblem(
  kind: SignerChoice["kind"],
  chainId: number,
  signer: Address,
  deployment: Deployment | undefined,
): string | undefined {
  if (kind === "anvil-dev-key" && chainId !== ANVIL_CHAIN_ID) {
    return "The anvil dev key is only allowed on the local anvil chain (31337).";
  }
  if (!deployment) return `No M3 deployment is known for chain ${chainId}.`;
  if (signer.toLowerCase() === deployment.owner.toLowerCase()) {
    return "That is the owner key. The console never signs as the owner; use the agent key.";
  }
  return undefined;
}

function viemChain(
  pub: PublicClient,
  wallet: WalletClient,
  chainId: number,
  d: Deployment,
  signer: Address,
): OnboardingChain {
  const read = <T>(address: Address, abi: Abi, functionName: string, args: unknown[] = []) =>
    pub.readContract({ address, abi, functionName, args }) as Promise<T>;

  async function write(
    address: Address,
    abi: Abi,
    functionName: string,
    args: unknown[],
  ): Promise<Hex> {
    try {
      const { request } = await pub.simulateContract({
        address,
        abi,
        functionName,
        args,
        account: wallet.account ?? signer,
      });
      const hash = await wallet.writeContract({ ...request, chain: null } as never);
      await pub.waitForTransactionReceipt({ hash });
      return hash;
    } catch (e) {
      if (e instanceof BaseError) {
        const r = e.walk((x) => x instanceof ContractFunctionRevertedError);
        if (r instanceof ContractFunctionRevertedError) {
          throw new ChainRevert(
            r.data
              ? { errorName: r.data.errorName, args: r.data.args as readonly unknown[] }
              : undefined,
          );
        }
      }
      throw e;
    }
  }

  return {
    chainId,
    deployment: d,
    signer,
    isVerified: (w) => read<boolean>(d.identityRegistry, identityRegistryAbi, "isVerified", [w]),
    async snapshot(assetId) {
      const r = d.assetRegistry;
      const [
        state,
        tokenOf,
        assetOfToken,
        totalSupply,
        reserve,
        lastSeq,
        valuationTs,
        window,
        metadataHash,
        block,
      ] = await Promise.all([
        read<number>(r, assetRegistryAbi, "stateOf", [assetId]),
        read<Address>(r, assetRegistryAbi, "tokenOf", [assetId]),
        read<Hex>(r, assetRegistryAbi, "assetOfToken", [d.token]),
        read<bigint>(d.token, tokenAbi, "totalSupply"),
        read<bigint>(r, assetRegistryAbi, "reserveOf", [assetId]),
        read<bigint>(r, assetRegistryAbi, "lastSequenceOf", [assetId]),
        read<bigint>(r, assetRegistryAbi, "valuationTsOf", [assetId]),
        read<bigint>(r, assetRegistryAbi, "valuationWindowOf", [assetId]),
        read<Hex>(r, assetRegistryAbi, "metadataHashOf", [assetId]),
        pub.getBlock(),
      ]);
      const src = d.attestationSource;
      const has = await read<boolean>(src, custodianAttestationSourceAbi, "hasAttestation", [
        assetId,
      ]);
      const latest = has
        ? await read<{ seq: bigint }>(src, custodianAttestationSourceAbi, "latest", [assetId])
        : { seq: 0n };
      const envelope = await read<Hex>(src, custodianAttestationSourceAbi, "envelopeHashOf", [
        assetId,
      ]);
      return {
        state: Number(state) as AssetStateValue,
        tokenOf,
        assetOfToken,
        totalSupply,
        reserve,
        lastSeq: BigInt(lastSeq),
        valuationTs: BigInt(valuationTs),
        window: BigInt(window),
        sourceSeq: BigInt(latest.seq),
        sourceEnvelopeHash: envelope,
        metadataHash,
        now: block.timestamp,
      };
    },
    register: (assetId, hash, slug) =>
      write(d.assetRegistry, assetRegistryAbi, "register", [assetId, hash, slug]),
    submitAttestation: (att, envelopeHash) =>
      write(d.attestationSource, custodianAttestationSourceAbi, "submitAttestation", [
        att,
        envelopeHash,
      ]),
    admit: (assetId, intended) =>
      write(d.assetRegistry, assetRegistryAbi, "admit", [assetId, intended]),
    mint: (to, amount) => write(d.token, tokenAbi, "mint", [to, amount]),
  };
}
