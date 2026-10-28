// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

/**
 * @title OwnerAgentRoles
 * @notice The two ERC-3643 roles mapped onto key tiers (ADR 0015): an immutable `owner`
 *         (2-of-3 multisig, configuration) and a set of `agent`s (Tier 1 service key,
 *         operations). Shared by the identity registries and the token.
 * @dev No ownership transfer: deployments are immutable (ADR 0025). Agent changes are not
 *      idempotent, for the same multisig reason as `IAssetRegistry.addAgent`: a change the
 *      multisig signed must either happen and emit, or revert.
 */
abstract contract OwnerAgentRoles {
    /// @notice The governance multisig. Fixed for the life of the contract.
    address public immutable owner;

    mapping(address => bool) private _agents;

    event AgentAdded(address indexed agent);
    event AgentRemoved(address indexed agent);

    /// @notice An owner-only function was called by someone else.
    error NotOwner(address caller);
    /// @notice An agent-only function was called by a non-agent.
    error NotAuthorisedAgent(address caller);
    /// @notice `addAgent` / `removeAgent` with `address(0)`.
    error InvalidAgent(address account);
    /// @notice `addAgent` on an agent, or `removeAgent` on a non-agent.
    error AgentUnchanged(address account);
    /// @notice A required address argument was `address(0)`.
    error ZeroAddress();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier onlyAgent() {
        if (!_agents[msg.sender]) revert NotAuthorisedAgent(msg.sender);
        _;
    }

    constructor(address owner_) {
        if (owner_ == address(0)) revert NotOwner(address(0));
        owner = owner_;
    }

    /// @notice Returns true if `account` holds the agent role.
    function isAgent(address account) public view returns (bool) {
        return _agents[account];
    }

    /// @notice Grants the agent role. Owner-only.
    function addAgent(address account) external onlyOwner {
        if (account == address(0)) revert InvalidAgent(account);
        if (_agents[account]) revert AgentUnchanged(account);
        _agents[account] = true;
        emit AgentAdded(account);
    }

    /// @notice Revokes the agent role. Owner-only.
    function removeAgent(address account) external onlyOwner {
        if (account == address(0)) revert InvalidAgent(account);
        if (!_agents[account]) revert AgentUnchanged(account);
        _agents[account] = false;
        emit AgentRemoved(account);
    }
}
