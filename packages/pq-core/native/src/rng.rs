//! Single-source entropy plumbing for Rust and the vendored PQClean C.

use crate::PqError;
use core::cell::Cell;

#[cfg(feature = "kat")]
use core::cell::RefCell;
#[cfg(feature = "kat")]
use zeroize::Zeroize;

thread_local! {
    // PQClean discards randombytes()'s return value. A failure is therefore
    // sticky until the safe wrapper that began the operation observes it.
    static OPERATION_FAILED: Cell<bool> = const { Cell::new(false) };
}

#[cfg(feature = "kat")]
struct KatEntropy {
    bytes: Vec<u8>,
    offset: usize,
}

#[cfg(feature = "kat")]
impl Drop for KatEntropy {
    fn drop(&mut self) {
        self.bytes.zeroize();
    }
}

#[cfg(feature = "kat")]
thread_local! {
    static KAT_ENTROPY: RefCell<Option<KatEntropy>> = const { RefCell::new(None) };
}

#[cfg(test)]
thread_local! {
    static FAIL_NEXT_DRAW: Cell<bool> = const { Cell::new(false) };
}

/// Clear the entropy status before entering a PQClean operation.
pub(crate) fn begin_operation() {
    OPERATION_FAILED.with(|failed| failed.set(false));
}

/// Consume the entropy status after returning from PQClean.
pub(crate) fn take_operation_failure() -> bool {
    OPERATION_FAILED.with(|failed| failed.replace(false))
}

fn mark_operation_failed() {
    OPERATION_FAILED.with(|failed| failed.set(true));
}

fn operation_failed() -> bool {
    OPERATION_FAILED.with(Cell::get)
}

/// Fill exactly one buffer from the platform CSPRNG, without retrying.
///
/// A failed backend may have written a prefix before returning. The complete
/// buffer is cleared before the error crosses this boundary.
pub(crate) fn fill(buffer: &mut [u8]) -> Result<(), PqError> {
    if buffer.is_empty() {
        return Ok(());
    }

    #[cfg(feature = "kat")]
    let used_kat_entropy = KAT_ENTROPY.with(|slot| {
        let mut slot = slot.borrow_mut();
        let Some(entropy) = slot.as_mut() else {
            return false;
        };
        let Some(end) = entropy.offset.checked_add(buffer.len()) else {
            buffer.fill(0);
            mark_operation_failed();
            return true;
        };
        if end > entropy.bytes.len() {
            buffer.fill(0);
            mark_operation_failed();
        } else {
            buffer.copy_from_slice(&entropy.bytes[entropy.offset..end]);
            entropy.offset = end;
        }
        true
    });
    #[cfg(feature = "kat")]
    if used_kat_entropy {
        return if operation_failed() {
            Err(PqError::RngFailure)
        } else {
            Ok(())
        };
    }

    #[cfg(test)]
    if FAIL_NEXT_DRAW.with(|fail| fail.replace(false)) {
        // Model the strongest failure case: the backend changed a prefix and
        // then reported failure. Callers must still observe only zeros.
        buffer[0] = 0xa5;
        buffer.fill(0);
        return Err(PqError::RngFailure);
    }

    getrandom::getrandom(buffer).map_err(|_| {
        buffer.fill(0);
        PqError::RngFailure
    })
}

#[cfg(feature = "kat")]
pub(crate) fn with_kat_entropy<T>(
    bytes: &[u8],
    operation: impl FnOnce() -> T,
) -> Result<T, PqError> {
    let already_active = KAT_ENTROPY.with(|slot| {
        let mut slot = slot.borrow_mut();
        if slot.is_some() {
            true
        } else {
            *slot = Some(KatEntropy {
                bytes: bytes.to_vec(),
                offset: 0,
            });
            false
        }
    });
    if already_active {
        return Err(PqError::InternalError);
    }

    let result = operation();
    let consumed_all = KAT_ENTROPY.with(|slot| {
        let state = slot.borrow_mut().take().expect("KAT entropy scope exists");
        state.offset == state.bytes.len()
    });
    if consumed_all {
        Ok(result)
    } else {
        Err(PqError::InternalError)
    }
}

/// Entropy symbol consumed by every vendored PQClean scheme.
///
/// PQClean callers ignore the return value, so this records a sticky failure in
/// addition to returning `-1`. The safe operation wrapper wipes its outputs and
/// returns `PqError::RngFailure` after the C function unwinds.
///
/// # Safety
///
/// `output` must be valid for writes of `n` bytes when `n` is non-zero.
#[no_mangle]
pub unsafe extern "C" fn PQCLEAN_randombytes(output: *mut u8, n: usize) -> core::ffi::c_int {
    if n == 0 {
        return 0;
    }

    if output.is_null() {
        mark_operation_failed();
        return -1;
    }

    // SAFETY: the caller provides a non-null buffer valid for `n` writes.
    let buffer = unsafe { core::slice::from_raw_parts_mut(output, n) };

    // Once a draw fails, do not perform later draws from the same C operation.
    if operation_failed() {
        buffer.fill(0);
        return -1;
    }

    match fill(buffer) {
        Ok(()) => 0,
        Err(PqError::RngFailure) => {
            mark_operation_failed();
            -1
        }
        Err(_) => unreachable!("rng::fill has one error variant"),
    }
}

#[cfg(test)]
pub(crate) fn fail_next_draw() {
    FAIL_NEXT_DRAW.with(|fail| fail.set(true));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn failed_draw_clears_a_partially_written_buffer() {
        let mut output = [0x5a; 32];
        fail_next_draw();

        assert_eq!(fill(&mut output), Err(PqError::RngFailure));
        assert_eq!(output, [0u8; 32]);
    }

    #[test]
    fn c_failure_is_sticky_for_one_operation() {
        let mut first = [0x5a; 32];
        let mut second = [0x5a; 32];
        begin_operation();
        fail_next_draw();

        // SAFETY: both arrays are valid for their complete lengths.
        unsafe {
            assert_eq!(PQCLEAN_randombytes(first.as_mut_ptr(), first.len()), -1);
            assert_eq!(PQCLEAN_randombytes(second.as_mut_ptr(), second.len()), -1);
        }

        assert_eq!(first, [0u8; 32]);
        assert_eq!(second, [0u8; 32]);
        assert!(take_operation_failure());
    }
}
