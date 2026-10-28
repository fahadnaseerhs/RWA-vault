/**
 * T6.1a stage 1: clause 1 off-chain (ADR 0027) for the interim MS1 fixture attestation.
 *
 * The custodian's ML-DSA-65 signature is checked here with the pq-core napi addon, and a
 * verified file is written for `contracts/script/OnboardAsset.s.sol`, which never runs a
 * subprocess. The real M2 envelope replaces the format below behind the same two seams:
 * the verified file and `IReserveAttestationSource` (T6.1a spec §2, §7).
 */
import { existsSync, readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { encodeAbiParameters, hexToBytes, keccak256, toBytes, toHex } from "viem";

export const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
export const DEFAULT_ADDON = resolve(REPO_ROOT, "packages/pq-core/pq-core.node");

export const ATTESTATION_FORMAT = "rwa-vault/ms1-fixture-attestation@0";
export const ATTESTATION_ALGORITHM = "ML-DSA-65";
export const ATTESTATION_FIELDS = [
  "format",
  "algorithm",
  "chainId",
  "assetRef",
  "reserve",
  "seq",
  "valuationTs",
  "signature",
];
export const ANVIL_CHAIN_ID = 31337;

/** Exit codes: 1 bad input, 2 waiting for the owner multisig, 3 attestation rejected, 4 stage 2 stopped. */
export const EXIT = { INPUT: 1, WAITING_FOR_OWNER: 2, ATTESTATION: 3, SCRIPT_FAILED: 4 };

export const BAD_SIGNATURE_SENTENCE =
  "The custodian's signature on this attestation is not valid for the registered custodian key.";

export class OnboardError extends Error {
  /** @param {string} code named error, e.g. "BadAttestationSig(...)" @param {number} exitCode */
  constructor(code, exitCode, message) {
    super(`${code}: ${message}`);
    this.code = code;
    this.exitCode = exitCode;
  }
}

/** The pq-core napi addon (`pnpm pq:addon` builds it). */
export function loadAddon(path = process.env.PQ_CORE_ADDON ?? DEFAULT_ADDON) {
  try {
    return createRequire(import.meta.url)(path);
  } catch (e) {
    throw new OnboardError(
      "PqCoreAddonMissing",
      EXIT.INPUT,
      `cannot load the pq-core addon at ${path}; run \`pnpm pq:addon\` first (${e.message})`,
    );
  }
}

export const assetIdOf = (slug) => keccak256(toBytes(slug));

/** The signed message: abi.encode(format, chainId, assetId, reserve, seq, valuationTs). */
export function attestationMessage({ chainId, assetRef, reserve, seq, valuationTs }) {
  return hexToBytes(
    encodeAbiParameters(
      [
        { type: "string" },
        { type: "uint256" },
        { type: "bytes32" },
        { type: "uint256" },
        { type: "uint64" },
        { type: "uint64" },
      ],
      [
        ATTESTATION_FORMAT,
        BigInt(chainId),
        assetIdOf(assetRef),
        BigInt(reserve),
        BigInt(seq),
        BigInt(valuationTs),
      ],
    ),
  );
}

/** The canonical eight-field metadataHash (T6.1a spec §3); OnboardAsset.metadataHash is the twin. */
export function metadataHash(input) {
  const vb = input.valuationBasis;
  return keccak256(
    encodeAbiParameters(
      [
        { type: "string" },
        { type: "string" },
        { type: "uint256" },
        { type: "uint16" },
        { type: "string" },
        { type: "string" },
        { type: "uint256" },
        { type: "string" },
      ],
      [
        input.assetId,
        input.description,
        BigInt(input.grossWeight),
        input.fineness,
        vb.source,
        vb.currency,
        BigInt(vb.unitValue),
        input.custodianId,
      ],
    ),
  );
}

const malformed = (msg) => new OnboardError("MalformedAttestation", EXIT.ATTESTATION, msg);

/** Parses and shape-checks the envelope; unknown fields (a `publicKey`, say) are rejected. */
export function parseAttestation(bytes) {
  let a;
  try {
    a = JSON.parse(Buffer.from(bytes).toString("utf8"));
  } catch {
    throw malformed("the attestation file is not JSON");
  }
  if (typeof a !== "object" || a === null || Array.isArray(a))
    throw malformed("must be a JSON object");
  for (const k of Object.keys(a)) {
    if (!ATTESTATION_FIELDS.includes(k)) {
      throw malformed(
        `unknown field "${k}"; the custodian key is never read from the envelope (script/input/custodian.json)`,
      );
    }
  }
  for (const k of ATTESTATION_FIELDS)
    if (!Object.hasOwn(a, k)) throw malformed(`missing field "${k}"`);
  if (a.format !== ATTESTATION_FORMAT) throw malformed(`format must be "${ATTESTATION_FORMAT}"`);
  if (a.algorithm !== ATTESTATION_ALGORITHM)
    throw malformed(`algorithm must be "${ATTESTATION_ALGORITHM}"`);
  if (!Number.isSafeInteger(a.chainId) || a.chainId <= 0)
    throw malformed("chainId must be a positive integer");
  if (typeof a.assetRef !== "string" || a.assetRef.length === 0)
    throw malformed("assetRef must be a string");
  if (
    typeof a.reserve !== "string" ||
    !/^(0|[1-9][0-9]*)$/.test(a.reserve) ||
    BigInt(a.reserve) >= 2n ** 256n
  )
    throw malformed("reserve must be a base-10 uint256 string");
  for (const k of ["seq", "valuationTs"]) {
    if (!Number.isSafeInteger(a[k]) || a[k] <= 0)
      throw malformed(`${k} must be a positive integer`);
  }
  if (typeof a.signature !== "string" || !/^[A-Za-z0-9+/]+={0,2}$/.test(a.signature))
    throw malformed("signature must be base64");
  return a;
}

/**
 * Where the custodian key is read from. The registered key is committed in
 * `contracts/script/input/`. On anvil only, a devnet fixture key written by
 * `make-fixture-attestation.mjs` to `contracts/.onboard/` (gitignored) takes precedence, so a
 * rehearsal never rewrites tracked files.
 */
export function custodianKeyDir(contractsDir, chainId) {
  const devnet = resolve(contractsDir, ".onboard");
  if (chainId === ANVIL_CHAIN_ID && existsSync(resolve(devnet, "custodian.json"))) return devnet;
  return resolve(contractsDir, "script/input");
}

/** Reads the custodian key from `dir` and checks it against `custodianKeyHash`. */
export function readCustodianKey(dir) {
  const pubPath = resolve(dir, "custodian.mldsa65.pub");
  const cfgPath = resolve(dir, "custodian.json");
  if (!existsSync(pubPath) || !existsSync(cfgPath)) {
    throw new OnboardError(
      "CustodianKeyMissing",
      EXIT.ATTESTATION,
      `no custodian key at ${dir} (custodian.mldsa65.pub and custodian.json)`,
    );
  }
  const pub = readFileSync(pubPath);
  const cfg = JSON.parse(readFileSync(cfgPath, "utf8"));
  const got = keccak256(pub);
  if (got.toLowerCase() !== String(cfg.custodianKeyHash).toLowerCase()) {
    throw new OnboardError(
      `CustodianKeyMismatch(${cfg.custodianKeyHash}, ${got})`,
      EXIT.ATTESTATION,
      "custodian.mldsa65.pub does not hash to custodianKeyHash in custodian.json",
    );
  }
  return pub;
}

/**
 * Clause 1 and the envelope cross-checks (spec §2.3). The key is loaded only after the
 * chain and asset checks, through `loadPublicKey`.
 * @returns the verified record written to `.onboard/<slug>.verified.json`
 */
export async function verifyAttestation({
  attBytes,
  loadPublicKey,
  chainId,
  inputAssetRef,
  addon,
  now,
}) {
  const a = parseAttestation(attBytes);
  if (a.chainId !== chainId) {
    throw new OnboardError(
      `AttestationForOtherChain(${chainId}, ${a.chainId})`,
      EXIT.ATTESTATION,
      `this attestation was signed for chain ${a.chainId}, but the RPC is chain ${chainId}`,
    );
  }
  if (a.assetRef !== inputAssetRef) {
    throw new OnboardError(
      `AttestationForOtherAsset(${inputAssetRef}, ${a.assetRef})`,
      EXIT.ATTESTATION,
      `the input is for "${inputAssetRef}" but the attestation is for "${a.assetRef}"`,
    );
  }
  const publicKey = loadPublicKey();
  let ok = false;
  try {
    ok = await addon.verify(
      "ml-dsa-65",
      Buffer.from(publicKey),
      Buffer.from(attestationMessage(a)),
      Buffer.from(a.signature, "base64"),
    );
  } catch {
    ok = false; // a malformed signature is just an invalid one
  }
  if (!ok) throw new OnboardError("BadAttestationSig", EXIT.ATTESTATION, BAD_SIGNATURE_SENTENCE);

  const pkg = JSON.parse(readFileSync(resolve(REPO_ROOT, "packages/pq-core/package.json"), "utf8"));
  return {
    chainId: a.chainId,
    assetRef: a.assetRef,
    assetId: assetIdOf(a.assetRef),
    reserve: a.reserve,
    seq: a.seq,
    valuationTs: a.valuationTs,
    envelopeHash: keccak256(toHex(attBytes)),
    verifiedAt: new Date((now ?? Date.now() / 1000) * 1000).toISOString(),
    verifier: `pq-core ml-dsa-65 ${pkg.version}`,
  };
}

/** Builds and signs a fixture envelope (devnet only; the caller checks the chain). */
export async function signFixtureAttestation({
  addon,
  privateKey,
  chainId,
  assetRef,
  reserve,
  seq,
  valuationTs,
}) {
  const body = {
    format: ATTESTATION_FORMAT,
    algorithm: ATTESTATION_ALGORITHM,
    chainId,
    assetRef,
    reserve: String(reserve),
    seq,
    valuationTs,
  };
  const sig = await addon.sign(
    "ml-dsa-65",
    Buffer.from(privateKey),
    Buffer.from(attestationMessage(body)),
  );
  return { ...body, signature: Buffer.from(sig).toString("base64") };
}

/** Minimal JSON-RPC call, so stage 1 needs no node beyond the one it targets. */
export async function rpc(url, method, params = []) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  const body = await res.json();
  if (body.error) throw new Error(`${method}: ${body.error.message}`);
  return body.result;
}
