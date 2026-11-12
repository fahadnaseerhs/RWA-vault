// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IClaimIssuer} from "../vendor/onchain-id/interface/IClaimIssuer.sol";
import {ITrustedIssuersRegistry} from "./interfaces/ITrustedIssuersRegistry.sol";

/**
 * @title TrustedIssuersRegistry
 * @notice The list of claim issuers the token trusts, and the topics each may attest.
 * @dev Module 3, task T1.4. "Who do we trust about what" — not merely "who do we trust".
 *
 *      Two lookups exist and they are NOT interchangeable:
 *      - `isTrustedIssuer(addr)` — trusted for anything?
 *      - `hasClaimTopic(addr, topic)` / `getTrustedIssuersForClaimTopic(topic)` — trusted for THIS topic?
 *
 *      `IdentityRegistry.isVerified` must use the second. An issuer trusted for some topic is
 *      not trusted for this one, and an implementation that reaches for `isTrustedIssuer` because
 *      it reads more naturally will accept a claim from a genuinely-trusted issuer who was never
 *      authorised for KYC. That is AC-T1-7 and the most likely defect in all of T1.
 *
 *      A cap on issuers per topic bounds `isVerified`'s inner loop, which runs on every transfer
 *      and mint: without it, the owner could make the gate too expensive to call and brick
 *      transfers. Same reasoning as `ClaimTopicsRegistry.MAX_CLAIM_TOPICS`.
 *
 *      Plain deployment, constructor-wired, no initializer, no proxy (ADR 0025). Owner
 *      is the 2-of-3 multisig (ADR 0015), checked with a named error rather than
 *      OpenZeppelin `Ownable` so the onboarding script can translate it (T1 spec §6).
 *      NatSpec authored for RWA-Vault.
 */
contract TrustedIssuersRegistry is ITrustedIssuersRegistry {
    /**
     * @notice Upper bound on trusted issuers per topic.
     * @dev Not tidiness: `isVerified` loops over issuers per topic on every transfer and mint,
     *      so an unbounded list would let the owner make the token's gate too expensive to call.
     *      Same griefing rationale as `ClaimTopicsRegistry.MAX_CLAIM_TOPICS`.
     */
    uint256 public constant MAX_ISSUERS_PER_TOPIC = 10;

    /**
     * @notice The owner (2-of-3 multisig, ADR 0015). Immutable, with no `transferOwnership`.
     * @dev Keys rotate inside the multisig without its address changing: see
     *      `ClaimTopicsRegistry` NatSpec for the full rationale.
     */
    address public immutable owner;

    // ── Enumeration ──────────────────────────────────────────────────────────

    /// @dev All trusted issuers, for `getTrustedIssuers()`.
    IClaimIssuer[] private _trustedIssuers;

    /// @dev issuer address → 1-based index in `_trustedIssuers` (0 = not present).
    mapping(address => uint256) private _issuerIndex;

    // ── Per-issuer topics ────────────────────────────────────────────────────

    /// @dev issuer address → topics the issuer may attest.
    mapping(address => uint256[]) private _issuerTopics;

    // ── Per-topic issuer index (for O(1) `hasClaimTopic` and bounded `isVerified`) ──

    /// @dev topic → issuers authorised for that topic.
    mapping(uint256 => IClaimIssuer[]) private _topicIssuers;

    /// @dev issuer address → topic → 1-based index in `_topicIssuers[topic]` (0 = not present).
    mapping(address => mapping(uint256 => uint256)) private _topicIssuerIndex;

    // ── Errors ───────────────────────────────────────────────────────────────

    /// @notice An owner-only function was called by `caller`, who is not the owner.
    error NotOwner(address caller);

    /// @notice The constructor was given `address(0)` as the owner.
    error InvalidOwner(address owner_);

    /// @notice `addTrustedIssuer` with an issuer that is already registered.
    error IssuerAlreadyExists(address issuer);

    /// @notice A mutator was called for an issuer that is not registered.
    error IssuerNotFound(address issuer);

    /// @notice `addTrustedIssuer` or `updateIssuerClaimTopics` with an empty topic array.
    /// An issuer trusted for no topics is a row that can never be used.
    error EmptyClaimTopics();

    /// @notice `addTrustedIssuer` with an address that has no code. An issuer must be a contract;
    /// `extcodesize` is the check a cast cannot do (AC-T1-27).
    error IssuerHasNoCode(address issuer);

    /// @notice Adding an issuer to a topic would exceed {MAX_ISSUERS_PER_TOPIC}.
    error TooManyIssuersPerTopic(uint256 topic, uint256 max);

    /// @notice The same topic appears twice in the topics array.
    error DuplicateClaimTopic(uint256 topic);

    // ── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    // ── Constructor ──────────────────────────────────────────────────────────

    /// @param owner_ the 2-of-3 multisig. Must not be `address(0)`.
    constructor(address owner_) {
        if (owner_ == address(0)) revert InvalidOwner(owner_);
        owner = owner_;
    }

    // ── Mutators (all owner-only: adding an issuer is adding a KYC authority) ─

    /// @inheritdoc ITrustedIssuersRegistry
    /// @dev Owner-only. Reverts {IssuerHasNoCode}, {IssuerAlreadyExists},
    ///      {EmptyClaimTopics}, {TooManyIssuersPerTopic}, or {DuplicateClaimTopic}.
    function addTrustedIssuer(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics) external onlyOwner {
        address issuerAddr = address(_trustedIssuer);
        if (issuerAddr.code.length == 0) revert IssuerHasNoCode(issuerAddr);
        if (_issuerIndex[issuerAddr] != 0) revert IssuerAlreadyExists(issuerAddr);
        if (_claimTopics.length == 0) revert EmptyClaimTopics();

        // Register the issuer in the enumeration array.
        _trustedIssuers.push(_trustedIssuer);
        _issuerIndex[issuerAddr] = _trustedIssuers.length; // 1-based

        // Index the issuer under each topic. Duplicate detection uses the index:
        // the first iteration sets it to non-zero, so a duplicate in the same
        // input array is caught on the second pass.
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            uint256 topic = _claimTopics[i];
            if (_topicIssuerIndex[issuerAddr][topic] != 0) revert DuplicateClaimTopic(topic);
            if (_topicIssuers[topic].length >= MAX_ISSUERS_PER_TOPIC) {
                revert TooManyIssuersPerTopic(topic, MAX_ISSUERS_PER_TOPIC);
            }
            _topicIssuers[topic].push(_trustedIssuer);
            _topicIssuerIndex[issuerAddr][topic] = _topicIssuers[topic].length; // 1-based
        }
        _issuerTopics[issuerAddr] = _claimTopics;

        emit TrustedIssuerAdded(_trustedIssuer, _claimTopics);
    }

    /// @inheritdoc ITrustedIssuersRegistry
    /// @dev Owner-only. Reverts {IssuerNotFound}.
    function removeTrustedIssuer(IClaimIssuer _trustedIssuer) external onlyOwner {
        address issuerAddr = address(_trustedIssuer);
        uint256 idx = _issuerIndex[issuerAddr];
        if (idx == 0) revert IssuerNotFound(issuerAddr);

        // Remove from per-topic indexes first.
        uint256[] memory topics = _issuerTopics[issuerAddr];
        for (uint256 i = 0; i < topics.length; i++) {
            _removeIssuerFromTopic(issuerAddr, topics[i]);
        }
        delete _issuerTopics[issuerAddr];

        // Swap-and-pop from the enumeration array.
        uint256 lastIdx = _trustedIssuers.length; // 1-based length
        if (idx != lastIdx) {
            IClaimIssuer last = _trustedIssuers[lastIdx - 1];
            _trustedIssuers[idx - 1] = last;
            _issuerIndex[address(last)] = idx;
        }
        _trustedIssuers.pop();
        delete _issuerIndex[issuerAddr];

        emit TrustedIssuerRemoved(_trustedIssuer);
    }

    /// @inheritdoc ITrustedIssuersRegistry
    /// @dev Owner-only. Reverts {IssuerNotFound}, {EmptyClaimTopics},
    ///      {TooManyIssuersPerTopic}, or {DuplicateClaimTopic}.
    function updateIssuerClaimTopics(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics) external onlyOwner {
        address issuerAddr = address(_trustedIssuer);
        if (_issuerIndex[issuerAddr] == 0) revert IssuerNotFound(issuerAddr);
        if (_claimTopics.length == 0) revert EmptyClaimTopics();

        // Remove from all old topic indexes.
        uint256[] memory oldTopics = _issuerTopics[issuerAddr];
        for (uint256 i = 0; i < oldTopics.length; i++) {
            _removeIssuerFromTopic(issuerAddr, oldTopics[i]);
        }

        // Add to all new topic indexes (duplicate detection via index, same as add).
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            uint256 topic = _claimTopics[i];
            if (_topicIssuerIndex[issuerAddr][topic] != 0) revert DuplicateClaimTopic(topic);
            if (_topicIssuers[topic].length >= MAX_ISSUERS_PER_TOPIC) {
                revert TooManyIssuersPerTopic(topic, MAX_ISSUERS_PER_TOPIC);
            }
            _topicIssuers[topic].push(_trustedIssuer);
            _topicIssuerIndex[issuerAddr][topic] = _topicIssuers[topic].length;
        }
        _issuerTopics[issuerAddr] = _claimTopics;

        emit ClaimTopicsUpdated(_trustedIssuer, _claimTopics);
    }

    // ── Views ────────────────────────────────────────────────────────────────

    /// @inheritdoc ITrustedIssuersRegistry
    function getTrustedIssuers() external view returns (IClaimIssuer[] memory) {
        return _trustedIssuers;
    }

    /// @inheritdoc ITrustedIssuersRegistry
    /// @dev Returns ONLY the issuers authorised for this topic — not every issuer.
    ///      `isVerified` must use this (or `hasClaimTopic`), never `isTrustedIssuer`.
    function getTrustedIssuersForClaimTopic(uint256 claimTopic) external view returns (IClaimIssuer[] memory) {
        return _topicIssuers[claimTopic];
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function isTrustedIssuer(address _issuer) external view returns (bool) {
        return _issuerIndex[_issuer] != 0;
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function getTrustedIssuerClaimTopics(IClaimIssuer _trustedIssuer) external view returns (uint256[] memory) {
        return _issuerTopics[address(_trustedIssuer)];
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function hasClaimTopic(address _issuer, uint256 _claimTopic) external view returns (bool) {
        return _topicIssuerIndex[_issuer][_claimTopic] != 0;
    }

    // ── Internal ─────────────────────────────────────────────────────────────

    /// @dev Removes `issuerAddr` from `_topicIssuers[topic]` via swap-and-pop.
    function _removeIssuerFromTopic(address issuerAddr, uint256 topic) private {
        uint256 idx = _topicIssuerIndex[issuerAddr][topic]; // 1-based
        if (idx == 0) return; // not present for this topic (defensive)

        uint256 lastIdx = _topicIssuers[topic].length;
        if (idx != lastIdx) {
            IClaimIssuer last = _topicIssuers[topic][lastIdx - 1];
            _topicIssuers[topic][idx - 1] = last;
            _topicIssuerIndex[address(last)][topic] = idx;
        }
        _topicIssuers[topic].pop();
        delete _topicIssuerIndex[issuerAddr][topic];
    }
}
