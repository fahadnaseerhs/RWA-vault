/**
 * @module @rwa-vault/pq-core
 * @description M1 — Post-quantum cryptographic core.
 *
 * Public API surface for consumers. Re-exports types, errors, metadata,
 * and the two runtime adapters. No PQClean or implementation detail leaks
 * past this boundary.
 */

// Types and algorithm unions
export {
  PQ_SIGNATURE_ALGORITHMS,
  PQ_KEM_ALGORITHMS,
  PQ_ALGORITHMS,
  isPqSignatureAlgorithm,
  isPqKemAlgorithm,
} from "./types.js";
export type {
  PqSignatureAlgorithm,
  PqKemAlgorithm,
  PqAlgorithm,
  PqKeyPair,
  PqEncapsulation,
  PqSignatureMetadata,
  PqKemMetadata,
  PqSignatureApi,
  PqKemApi,
  PqCoreApi,
} from "./types.js";

// Errors
export {
  PQ_ERROR_CODES,
  PqError,
  UnsupportedAlgorithmError,
  AlgorithmKeyMismatchError,
  MalformedKeyError,
  MalformedSignatureError,
  MalformedCiphertextError,
  MessageTooLongError,
  RngFailureError,
  NotInitialisedError,
  InternalError,
  pqErrorFromCode,
} from "./errors.js";
export type { PqErrorCode } from "./errors.js";

// Metadata
export { SIGNATURE_METADATA, KEM_METADATA } from "./metadata.js";

// Adapters
export { createNativeAdapter } from "./native.js";
export { createWasmAdapter } from "./wasm.js";
