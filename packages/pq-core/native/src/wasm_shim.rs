//! Freestanding C allocation and termination symbols required by PQClean.
//!
//! Rust's `compiler_builtins` already supplies `memcpy`, `memset`, `memmove`,
//! and `memcmp` for `wasm32-unknown-unknown`. Keeping local loop-based copies
//! would let LLVM lower `memmove` back into a call to itself.

#[cfg(target_arch = "wasm32")]
use core::ffi::c_int;
use core::ffi::c_void;
use core::ptr;
use std::alloc::{alloc, dealloc, Layout};

// C `malloc` must provide alignment suitable for any ordinary C object. Keeping
// the header one full alignment unit also preserves that alignment in the
// returned payload pointer.
const MALLOC_ALIGN: usize = 16;
const HEADER_BYTES: usize = MALLOC_ALIGN;

/// Allocate C-owned WASM memory using Rust's process allocator.
#[cfg_attr(target_arch = "wasm32", no_mangle)]
pub unsafe extern "C" fn malloc(requested: usize) -> *mut c_void {
    let payload_bytes = requested.max(1);
    let Some(total_bytes) = HEADER_BYTES.checked_add(payload_bytes) else {
        return ptr::null_mut();
    };
    let Ok(layout) = Layout::from_size_align(total_bytes, MALLOC_ALIGN) else {
        return ptr::null_mut();
    };

    // SAFETY: `layout` has non-zero size and a valid power-of-two alignment.
    let allocation = unsafe { alloc(layout) };
    if allocation.is_null() {
        return ptr::null_mut();
    }

    // The allocation size is sufficient to reconstruct the exact Layout in
    // `free`; PQClean genuinely releases every incremental SHAKE context.
    // SAFETY: the allocation starts with at least HEADER_BYTES writable bytes.
    unsafe { allocation.cast::<usize>().write(total_bytes) };

    // SAFETY: HEADER_BYTES is inside the allocation and leaves at least one
    // payload byte. Its value preserves MALLOC_ALIGN.
    unsafe { allocation.add(HEADER_BYTES).cast() }
}

/// Release memory returned by [`malloc`].
#[cfg_attr(target_arch = "wasm32", no_mangle)]
pub unsafe extern "C" fn free(pointer: *mut c_void) {
    if pointer.is_null() {
        return;
    }

    // SAFETY: C's `free` contract requires either null or the exact pointer
    // returned by `malloc`, so the prefixed header belongs to this allocation.
    let allocation = unsafe { pointer.cast::<u8>().sub(HEADER_BYTES) };
    // SAFETY: `malloc` stored this value at the aligned allocation base.
    let total_bytes = unsafe { allocation.cast::<usize>().read() };
    let layout = Layout::from_size_align(total_bytes, MALLOC_ALIGN)
        .expect("malloc stored a valid allocation layout");

    // SAFETY: this is the same pointer and Layout returned to `alloc`.
    unsafe { dealloc(allocation, layout) };
}

/// Implement C `exit` as an immediate WebAssembly trap.
#[cfg(target_arch = "wasm32")]
#[no_mangle]
pub extern "C" fn exit(_status: c_int) -> ! {
    core::arch::wasm32::unreachable()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn malloc_is_aligned_and_writable() {
        // SAFETY: the test writes only within the requested allocation and then
        // releases the exact pointer returned by malloc.
        unsafe {
            let pointer = malloc(37).cast::<u8>();
            assert!(!pointer.is_null());
            assert_eq!(pointer as usize % MALLOC_ALIGN, 0);
            for index in 0..37 {
                pointer.add(index).write(index as u8);
            }
            for index in 0..37 {
                assert_eq!(pointer.add(index).read(), index as u8);
            }
            free(pointer.cast());
        }
    }

    #[test]
    fn zero_size_allocation_can_be_freed() {
        // SAFETY: zero-sized malloc still returns an owned allocation, and free
        // receives that exact pointer. A null return would also be valid C.
        unsafe {
            let pointer = malloc(0);
            free(pointer);
        }
    }

    #[test]
    fn freeing_null_is_a_no_op() {
        // SAFETY: C explicitly permits free(NULL).
        unsafe { free(ptr::null_mut()) };
    }
}
