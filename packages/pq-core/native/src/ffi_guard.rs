//! Test-only observation of calls that cross into vendored C.

#[cfg(test)]
use core::cell::Cell;

#[cfg(test)]
thread_local! {
    static CALLS: Cell<usize> = const { Cell::new(0) };
}

#[inline]
pub(crate) fn entered() {
    #[cfg(test)]
    CALLS.with(|calls| calls.set(calls.get() + 1));
}

#[cfg(test)]
pub(crate) fn count() -> usize {
    CALLS.with(Cell::get)
}
