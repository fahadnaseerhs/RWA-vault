//! Stable, payload-free errors for every pq-core runtime boundary.

use core::fmt;

/// The closed error set defined by ADR 0006.
///
/// Every variant is deliberately fieldless: errors may cross logs, native/WASM
/// bridges, and TypeScript boundaries, so none may retain bytes or secret lengths.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum PqError {
    /// The requested algorithm identifier is not supported for this operation.
    UnsupportedAlgorithm,
    /// The key type does not match the requested algorithm.
    AlgorithmKeyMismatch,
    /// A public or private key has an invalid encoding or length.
    MalformedKey,
    /// A signature has an invalid encoding or length.
    MalformedSignature,
    /// A KEM ciphertext has an invalid encoding or length.
    MalformedCiphertext,
    /// The message exceeds the one-mebibyte ADR 0006 limit.
    MessageTooLong,
    /// The platform cryptographic random source failed.
    RngFailure,
    /// The runtime bridge has not completed secure initialisation.
    NotInitialised,
    /// An invariant failed below the public API boundary.
    InternalError,
}

// These assignments compile only while every variant remains a unit variant.
// A tuple or struct payload of any type, including Vec<u8> or &[u8], makes its
// corresponding assignment a constructor/type mismatch at compile time.
const _: PqError = PqError::UnsupportedAlgorithm;
const _: PqError = PqError::AlgorithmKeyMismatch;
const _: PqError = PqError::MalformedKey;
const _: PqError = PqError::MalformedSignature;
const _: PqError = PqError::MalformedCiphertext;
const _: PqError = PqError::MessageTooLong;
const _: PqError = PqError::RngFailure;
const _: PqError = PqError::NotInitialised;
const _: PqError = PqError::InternalError;

// A newly added storage-bearing variant (for example `Other(Vec<u8>)`) makes
// the enum larger and fails compilation even if code() and message() are updated.
const _: () = assert!(core::mem::size_of::<PqError>() == 1);

impl PqError {
    /// Stable machine-readable code for bridge consumers.
    pub const fn code(self) -> &'static str {
        match self {
            Self::UnsupportedAlgorithm => "UNSUPPORTED_ALGORITHM",
            Self::AlgorithmKeyMismatch => "ALGORITHM_KEY_MISMATCH",
            Self::MalformedKey => "MALFORMED_KEY",
            Self::MalformedSignature => "MALFORMED_SIGNATURE",
            Self::MalformedCiphertext => "MALFORMED_CIPHERTEXT",
            Self::MessageTooLong => "MESSAGE_TOO_LONG",
            Self::RngFailure => "RNG_FAILURE",
            Self::NotInitialised => "NOT_INITIALISED",
            Self::InternalError => "INTERNAL_ERROR",
        }
    }

    const fn message(self) -> &'static str {
        match self {
            Self::UnsupportedAlgorithm => "unsupported post-quantum algorithm",
            Self::AlgorithmKeyMismatch => "algorithm and key type do not match",
            Self::MalformedKey => "malformed post-quantum key",
            Self::MalformedSignature => "malformed post-quantum signature",
            Self::MalformedCiphertext => "malformed post-quantum ciphertext",
            Self::MessageTooLong => "message exceeds the supported limit",
            Self::RngFailure => "secure random source unavailable",
            Self::NotInitialised => "post-quantum runtime is not initialised",
            Self::InternalError => "internal post-quantum operation failed",
        }
    }
}

impl fmt::Display for PqError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(self.message())
    }
}

impl std::error::Error for PqError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_error_has_fixed_code_and_display_text() {
        let cases = [
            (
                PqError::UnsupportedAlgorithm,
                "UNSUPPORTED_ALGORITHM",
                "unsupported post-quantum algorithm",
            ),
            (
                PqError::AlgorithmKeyMismatch,
                "ALGORITHM_KEY_MISMATCH",
                "algorithm and key type do not match",
            ),
            (
                PqError::MalformedKey,
                "MALFORMED_KEY",
                "malformed post-quantum key",
            ),
            (
                PqError::MalformedSignature,
                "MALFORMED_SIGNATURE",
                "malformed post-quantum signature",
            ),
            (
                PqError::MalformedCiphertext,
                "MALFORMED_CIPHERTEXT",
                "malformed post-quantum ciphertext",
            ),
            (
                PqError::MessageTooLong,
                "MESSAGE_TOO_LONG",
                "message exceeds the supported limit",
            ),
            (
                PqError::RngFailure,
                "RNG_FAILURE",
                "secure random source unavailable",
            ),
            (
                PqError::NotInitialised,
                "NOT_INITIALISED",
                "post-quantum runtime is not initialised",
            ),
            (
                PqError::InternalError,
                "INTERNAL_ERROR",
                "internal post-quantum operation failed",
            ),
        ];

        for (error, code, display) in cases {
            assert_eq!(error.code(), code);
            assert_eq!(error.to_string(), display);
        }
    }
}
