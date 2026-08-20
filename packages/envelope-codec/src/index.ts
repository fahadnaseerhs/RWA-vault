/**
 * M2 Envelope codec - the canonical structure every post-quantum signature covers.
 *
 * Each field removes one specific attack (proposal Table 3). The signed bytes are the
 * serialised envelope with the signature field zeroed; the anchored leaf is the
 * Keccak-256 hash of that same structure, so the anchor commits to the signature
 * and to its context.
 */

import type { PqSignatureAlgorithm } from "@rwa-vault/pq-core";

export interface PqEnvelope {
  /** Format evolution without ambiguity in the signed bytes. */
  version: number;
  /**
   * Cryptographic agility; prevents downgrade to a retired primitive.
   *
   * Narrowed to the signature algorithms: an envelope is a signed structure, so
   * a KEM identifier here is meaningless and is rejected at compile time rather
   * than by the M2 verifier's allow-list at runtime.
   */
  algorithm: PqSignatureAlgorithm;
  /** Cross-chain replay protection. */
  chainId: bigint;
  /** Cross-contract replay protection. */
  contract: string;
  /** Action-substitution protection: an intent is meaningless for any other action. */
  action: string;
  /** Binds the envelope to a key record in PQKeyRegistry. */
  signer: string;
  /** Same-signer replay protection; strictly incrementing per signer and action. */
  nonce: bigint;
  /** Delayed-execution protection: 90s for user intents, 3600s for attestations. */
  validFrom: number;
  validTo: number;
  /** Payload-substitution protection: the executed payload cannot differ from the signed one. */
  payloadHash: string;
}
