/**
 * Canonical ADR 0006 metadata table, mirroring ALGORITHM_METADATA in Rust.
 *
 * This is the single source of truth for the TypeScript side. Both adapters
 * return metadata from this table rather than computing it themselves, so
 * the contract-equivalence test (S3-10) only needs to assert that Rust and
 * this table agree, not that each adapter independently reproduces the
 * values.
 */

import type {
  PqSignatureAlgorithm,
  PqKemAlgorithm,
  PqSignatureMetadata,
  PqKemMetadata,
} from "./types.js";

export const SIGNATURE_METADATA: Record<PqSignatureAlgorithm, PqSignatureMetadata> = {
  "falcon-512": {
    algorithm: "falcon-512",
    publicKeyBytes: 897,
    privateKeyBytes: 1281,
    signatureBytes: 666,
  },
  "ml-dsa-44": {
    algorithm: "ml-dsa-44",
    publicKeyBytes: 1312,
    privateKeyBytes: 2560,
    signatureBytes: 2420,
  },
  "ml-dsa-65": {
    algorithm: "ml-dsa-65",
    publicKeyBytes: 1952,
    privateKeyBytes: 4032,
    signatureBytes: 3309,
  },
  "slh-dsa-sha2-128s": {
    algorithm: "slh-dsa-sha2-128s",
    publicKeyBytes: 32,
    privateKeyBytes: 64,
    signatureBytes: 7856,
  },
};

export const KEM_METADATA: Record<PqKemAlgorithm, PqKemMetadata> = {
  "ml-kem-768": {
    algorithm: "ml-kem-768",
    publicKeyBytes: 1184,
    privateKeyBytes: 2400,
    ciphertextBytes: 1088,
    sharedSecretBytes: 32,
  },
  "ml-kem-1024": {
    algorithm: "ml-kem-1024",
    publicKeyBytes: 1568,
    privateKeyBytes: 3168,
    ciphertextBytes: 1568,
    sharedSecretBytes: 32,
  },
};
