// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IClaimTopicsRegistry} from "./interfaces/IClaimTopicsRegistry.sol";

/**
 * @title ClaimTopicsRegistry
 * @notice The set of claim topics a wallet's identity must hold to count as verified.
 * @dev Module 3, task T1.3. For MS1 the set is exactly one topic, `KYC_TOPIC` (Q02 = A),
 *      and its number is permanent (Q24 = A, ADR 0029): every KYC claim is signed
 *      against it, so changing it would invalidate every claim already issued.
 *
 *      The set can never be empty, and can never lose `KYC_TOPIC`, by construction. An
 *      empty set makes `IdentityRegistry.isVerified` vacuously true ("every required topic
 *      has a valid claim" holds when none are required), which would let every wallet hold
 *      the token. Removing `KYC_TOPIC` while another topic remains is the same fail-open in
 *      a non-empty disguise: the rule would silently change from "is KYC'd" to "holds the
 *      other topic". So the constructor seeds `KYC_TOPIC`, removing the last topic reverts
 *      {TopicSetCannotBeEmpty}, and removing `KYC_TOPIC` reverts {KycTopicIsPermanent}.
 *      Spec: Obsidian note "T1 - Identity Layer" §4.
 *
 *      Plain deployment, constructor-wired, no initializer, no proxy (ADR 0025). Owner
 *      is the 2-of-3 multisig (ADR 0015), checked with a named error rather than
 *      OpenZeppelin `Ownable` so the onboarding script can translate it (T1 spec §6).
 *      NatSpec authored for RWA-Vault.
 */
contract ClaimTopicsRegistry is IClaimTopicsRegistry {
    /// @notice The permanent KYC claim topic (Q24 = A, ADR 0029). Never change it.
    uint256 public constant KYC_TOPIC = 1;

    /**
     * @notice Upper bound on required topics.
     * @dev Not tidiness: `isVerified` runs on every transfer and mint and loops over every
     *      topic, so an unbounded list would let the owner make the token's own gate too
     *      expensive to call. `5` is a measured choice, not a round number (Q27 = B, 2026-11-12).
     *
     *      MEASURED COST of `IdentityRegistry.isVerified` against the real vendored `Identity`
     *      and `ClaimIssuer`, solc 0.8.26, `evm_version = "cancun"`, `optimizer_runs = 200`:
     *
     *        topics |    cold |   warm
     *             1 |  93,149 | 22,143
     *             3 | 197,372 | 58,366
     *             5 | 301,611 | 94,605   <- this cap
     *      marginal | ~52,116 | ~18,115
     *
     *      COLD is the figure that matters: a transfer is the first thing in its transaction to
     *      touch this registry, the identity and the issuer, so it pays cold-access prices. The
     *      warm column is a repeat call in the same transaction and understates a transfer by
     *      roughly 3.2x. At MS1's single topic a transfer pays ~93k here; at the cap, ~302k,
     *      before the token's own cost and before any compliance module.
     *
     *      Why 5 and not more: the cap exists to bound a cost the owner can impose on holders
     *      unilaterally, and 15 (the value this replaced) extrapolates to ~820k cold per
     *      verification. 5 leaves headroom for KYC + AML + accreditation + country + one spare.
     *
     *      Why a low cap is the safe error: `IdentityRegistry.setClaimTopicsRegistry` is owner-only,
     *      so a cap that proves too tight is fixable by deploying a replacement registry with a
     *      higher constant and repointing (ADR 0025 forbids proxies, not replacement). A cap that
     *      is too high is not fixable in the same way, because it is never observed as a failure.
     */
    uint256 public constant MAX_CLAIM_TOPICS = 5;

    /**
     * @notice The owner (2-of-3 multisig, ADR 0015). Immutable, with no `transferOwnership`.
     * @dev Keys rotate inside the multisig without its address changing, so a 2-of-3 that
     *      loses one key replaces the signer and this registry keeps pointing at the same
     *      owner. A transfer function would add the one call that lets a compromised owner
     *      lock everyone out permanently.
     */
    address public immutable owner;

    uint256[] private _claimTopics;

    /// @notice An owner-only function was called by `caller`, who is not the owner.
    error NotOwner(address caller);

    /// @notice The constructor was given `address(0)` as the owner.
    error InvalidOwner(address owner);

    /// @notice `addClaimTopic` with a topic that is already required.
    error ClaimTopicAlreadyExists(uint256 claimTopic);

    /// @notice `removeClaimTopic` with a topic that is not in the set.
    error ClaimTopicNotFound(uint256 claimTopic);

    /// @notice `removeClaimTopic` would leave the set empty, which would make every wallet verified.
    error TopicSetCannotBeEmpty();

    /// @notice `removeClaimTopic(KYC_TOPIC)`: the KYC topic is permanent (Q24 = A, ADR 0029), even when other topics remain.
    error KycTopicIsPermanent();

    /// @notice `addClaimTopic` would exceed {MAX_CLAIM_TOPICS}.
    error TooManyClaimTopics(uint256 max);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    /**
     * @param owner_ the 2-of-3 multisig. Must not be `address(0)`.
     * @dev Seeds {KYC_TOPIC}, so this registry can never be deployed empty.
     */
    constructor(address owner_) {
        if (owner_ == address(0)) revert InvalidOwner(owner_);
        owner = owner_;
        _claimTopics.push(KYC_TOPIC);
        emit ClaimTopicAdded(KYC_TOPIC);
    }

    /// @inheritdoc IClaimTopicsRegistry
    /// @dev Owner-only. Reverts {ClaimTopicAlreadyExists} or {TooManyClaimTopics}.
    ///      OPERATIONAL HAZARD: adding a topic immediately unverifies every holder who lacks a valid claim for it,
    ///      blocking their transfers until the claim is issued — treat this as a freeze-equivalent action.
    function addClaimTopic(uint256 _claimTopic) external onlyOwner {
        uint256 n = _claimTopics.length;
        if (n >= MAX_CLAIM_TOPICS) revert TooManyClaimTopics(MAX_CLAIM_TOPICS);
        for (uint256 i = 0; i < n; i++) {
            if (_claimTopics[i] == _claimTopic) revert ClaimTopicAlreadyExists(_claimTopic);
        }
        _claimTopics.push(_claimTopic);
        emit ClaimTopicAdded(_claimTopic);
    }

    /// @inheritdoc IClaimTopicsRegistry
    /// @dev Owner-only. Reverts {KycTopicIsPermanent} for `KYC_TOPIC`, whether or not other
    ///      topics remain, and {ClaimTopicNotFound} for a topic not in the set.
    ///
    ///      Permanence is checked first because it is the refusal that is true in every case:
    ///      answering "the set cannot be empty" on `[KYC]` would invite "add another topic,
    ///      then remove KYC", which is exactly the fail-open path.
    ///
    ///      The {TopicSetCannotBeEmpty} guard is a BACKSTOP and is unreachable while the
    ///      permanence guard holds (the set always contains KYC, so a one-topic set is `[KYC]`
    ///      and is refused above). It is kept on purpose so emptiness stays protected if
    ///      permanence is ever removed or weakened. Do not delete it as dead code.
    function removeClaimTopic(uint256 _claimTopic) external onlyOwner {
        uint256 n = _claimTopics.length;
        for (uint256 i = 0; i < n; i++) {
            if (_claimTopics[i] == _claimTopic) {
                if (_claimTopic == KYC_TOPIC) revert KycTopicIsPermanent();
                if (n == 1) revert TopicSetCannotBeEmpty();
                _claimTopics[i] = _claimTopics[n - 1];
                _claimTopics.pop();
                emit ClaimTopicRemoved(_claimTopic);
                return;
            }
        }
        revert ClaimTopicNotFound(_claimTopic);
    }

    /// @inheritdoc IClaimTopicsRegistry
    /// @dev Anyone may call. Never empty.
    function getClaimTopics() external view returns (uint256[] memory) {
        return _claimTopics;
    }
}
