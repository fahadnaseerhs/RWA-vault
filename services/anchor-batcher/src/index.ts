/**
 * M9 Epoch anchor batcher.
 *
 * One Merkle root per epoch at ~43k gas, independent of the number of events - the
 * property the whole architecture exists to exploit. If the batcher fails, execution is
 * unaffected (the chain is the system of record) and the next anchor carries the
 * accumulated leaves; epoch numbering makes the gap explicit rather than hiding it.
 */

/** Epoch length, matched to the fastest asset class's liquidation heartbeat. */
export const EPOCH_SECONDS = 60;

/**
 * Sorted-pair hashing: siblings are ordered before hashing, which removes the need to
 * transmit proof position bits and matches OpenZeppelin's audited MerkleProof. An audit
 * trail whose proofs can only be checked by our own code is not an audit trail.
 */
export const SORTED_PAIR = true;
