/**
 * TypeScript error classes mirroring the nine PqError variants in Rust.
 *
 * Every class carries a stable `code` string identical to PqError::code()
 * in the Rust crate and the napi addon's JS error `code` property.
 * The shared fixture in the contract-equivalence test (S3-10) asserts that
 * these three surfaces never drift apart.
 */

export const PQ_ERROR_CODES = [
  "UNSUPPORTED_ALGORITHM",
  "ALGORITHM_KEY_MISMATCH",
  "MALFORMED_KEY",
  "MALFORMED_SIGNATURE",
  "MALFORMED_CIPHERTEXT",
  "MESSAGE_TOO_LONG",
  "RNG_FAILURE",
  "NOT_INITIALISED",
  "INTERNAL_ERROR",
] as const;

export type PqErrorCode = (typeof PQ_ERROR_CODES)[number];

export class PqError extends Error {
  readonly code: PqErrorCode;

  constructor(code: PqErrorCode, message?: string) {
    super(message ?? defaultMessage(code));
    this.name = "PqError";
    this.code = code;
  }
}

export class UnsupportedAlgorithmError extends PqError {
  constructor(message?: string) {
    super("UNSUPPORTED_ALGORITHM", message ?? "unsupported post-quantum algorithm");
  }
}

export class AlgorithmKeyMismatchError extends PqError {
  constructor(message?: string) {
    super("ALGORITHM_KEY_MISMATCH", message ?? "algorithm and key type do not match");
  }
}

export class MalformedKeyError extends PqError {
  constructor(message?: string) {
    super("MALFORMED_KEY", message ?? "malformed post-quantum key");
  }
}

export class MalformedSignatureError extends PqError {
  constructor(message?: string) {
    super("MALFORMED_SIGNATURE", message ?? "malformed post-quantum signature");
  }
}

export class MalformedCiphertextError extends PqError {
  constructor(message?: string) {
    super("MALFORMED_CIPHERTEXT", message ?? "malformed post-quantum ciphertext");
  }
}

export class MessageTooLongError extends PqError {
  constructor(message?: string) {
    super("MESSAGE_TOO_LONG", message ?? "message exceeds the supported limit");
  }
}

export class RngFailureError extends PqError {
  constructor(message?: string) {
    super("RNG_FAILURE", message ?? "secure random source unavailable");
  }
}

export class NotInitialisedError extends PqError {
  constructor(message?: string) {
    super("NOT_INITIALISED", message ?? "post-quantum runtime is not initialised");
  }
}

export class InternalError extends PqError {
  constructor(message?: string) {
    super("INTERNAL_ERROR", message ?? "internal post-quantum operation failed");
  }
}

function defaultMessage(code: PqErrorCode): string {
  switch (code) {
    case "UNSUPPORTED_ALGORITHM":
      return "unsupported post-quantum algorithm";
    case "ALGORITHM_KEY_MISMATCH":
      return "algorithm and key type do not match";
    case "MALFORMED_KEY":
      return "malformed post-quantum key";
    case "MALFORMED_SIGNATURE":
      return "malformed post-quantum signature";
    case "MALFORMED_CIPHERTEXT":
      return "malformed post-quantum ciphertext";
    case "MESSAGE_TOO_LONG":
      return "message exceeds the supported limit";
    case "RNG_FAILURE":
      return "secure random source unavailable";
    case "NOT_INITIALISED":
      return "post-quantum runtime is not initialised";
    case "INTERNAL_ERROR":
      return "internal post-quantum operation failed";
  }
}

export function pqErrorFromCode(code: string, message?: string): PqError {
  switch (code) {
    case "UNSUPPORTED_ALGORITHM":
      return new UnsupportedAlgorithmError(message);
    case "ALGORITHM_KEY_MISMATCH":
      return new AlgorithmKeyMismatchError(message);
    case "MALFORMED_KEY":
      return new MalformedKeyError(message);
    case "MALFORMED_SIGNATURE":
      return new MalformedSignatureError(message);
    case "MALFORMED_CIPHERTEXT":
      return new MalformedCiphertextError(message);
    case "MESSAGE_TOO_LONG":
      return new MessageTooLongError(message);
    case "RNG_FAILURE":
      return new RngFailureError(message);
    case "NOT_INITIALISED":
      return new NotInitialisedError(message);
    case "INTERNAL_ERROR":
      return new InternalError(message);
    default:
      return new PqError("INTERNAL_ERROR", message ?? `unknown error code: ${code}`);
  }
}
