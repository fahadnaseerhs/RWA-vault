/**
 * Byte-oriented types, metadata types, and algorithm unions for pq-core.
 *
 * Every runtime adapter (native and WASM) implements the same contract
 * interfaces defined here. No `any` appears in this file.
 */

// ---------------------------------------------------------------------------
// Algorithm unions
// ---------------------------------------------------------------------------

export const PQ_SIGNATURE_ALGORITHMS = [
  "falcon-512",
  "ml-dsa-44",
  "ml-dsa-65",
  "slh-dsa-sha2-128s",
] as const;

export type PqSignatureAlgorithm = (typeof PQ_SIGNATURE_ALGORITHMS)[number];

export const PQ_KEM_ALGORITHMS = ["ml-kem-768", "ml-kem-1024"] as const;

export type PqKemAlgorithm = (typeof PQ_KEM_ALGORITHMS)[number];

export type PqAlgorithm = PqSignatureAlgorithm | PqKemAlgorithm;

export const PQ_ALGORITHMS: readonly PqAlgorithm[] = [
  ...PQ_SIGNATURE_ALGORITHMS,
  ...PQ_KEM_ALGORITHMS,
] as const;

// ---------------------------------------------------------------------------
// Narrowing predicates
// ---------------------------------------------------------------------------

export function isPqSignatureAlgorithm(algorithm: unknown): algorithm is PqSignatureAlgorithm {
  return (
    typeof algorithm === "string" &&
    (PQ_SIGNATURE_ALGORITHMS as readonly string[]).includes(algorithm)
  );
}

export function isPqKemAlgorithm(algorithm: unknown): algorithm is PqKemAlgorithm {
  return (
    typeof algorithm === "string" && (PQ_KEM_ALGORITHMS as readonly string[]).includes(algorithm)
  );
}

// ---------------------------------------------------------------------------
// Byte containers
// ---------------------------------------------------------------------------

export interface PqKeyPair {
  readonly publicKey: Uint8Array;
  readonly privateKey: Uint8Array;
}

export interface PqEncapsulation {
  readonly ciphertext: Uint8Array;
  readonly sharedSecret: Uint8Array;
}

// ---------------------------------------------------------------------------
// Metadata
// ---------------------------------------------------------------------------

export interface PqSignatureMetadata {
  readonly algorithm: PqSignatureAlgorithm;
  readonly publicKeyBytes: number;
  readonly privateKeyBytes: number;
  readonly signatureBytes: number;
}

export interface PqKemMetadata {
  readonly algorithm: PqKemAlgorithm;
  readonly publicKeyBytes: number;
  readonly privateKeyBytes: number;
  readonly ciphertextBytes: number;
  readonly sharedSecretBytes: number;
}

// ---------------------------------------------------------------------------
// Adapter contract interfaces
// ---------------------------------------------------------------------------

export interface PqSignatureApi {
  keygen(algorithm: PqSignatureAlgorithm): Promise<PqKeyPair>;
  sign(
    algorithm: PqSignatureAlgorithm,
    privateKey: Uint8Array,
    message: Uint8Array,
  ): Promise<Uint8Array>;
  verify(
    algorithm: PqSignatureAlgorithm,
    publicKey: Uint8Array,
    message: Uint8Array,
    signature: Uint8Array,
  ): Promise<boolean>;
  metadata(algorithm: PqSignatureAlgorithm): PqSignatureMetadata;
}

export interface PqKemApi {
  kemKeygen(algorithm: PqKemAlgorithm): Promise<PqKeyPair>;
  encapsulate(algorithm: PqKemAlgorithm, publicKey: Uint8Array): Promise<PqEncapsulation>;
  decapsulate(
    algorithm: PqKemAlgorithm,
    privateKey: Uint8Array,
    ciphertext: Uint8Array,
  ): Promise<Uint8Array>;
  kemMetadata(algorithm: PqKemAlgorithm): PqKemMetadata;
}

export interface PqCoreApi extends PqSignatureApi, PqKemApi {
  init(): Promise<void>;
}

// ---------------------------------------------------------------------------
// Compile-time backstop (S2-13): a KEM id must not reach sign()
// ---------------------------------------------------------------------------

type AssertTrue<T extends true> = T;
type SignSelectorRejectsKem = "ml-kem-768" extends Parameters<PqSignatureApi["sign"]>[0]
  ? false
  : true;
type _S2_13KemCannotReachSign = AssertTrue<SignSelectorRejectsKem>;
