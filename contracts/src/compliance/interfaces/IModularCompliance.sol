// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IModularCompliance
 * @notice Binds a token to a stack of transfer-rule modules and answers
 *         "does this transfer comply?" alongside the identity check.
 * @dev While the Identity Registry answers "who may hold" (per wallet), compliance
 *      answers "is this movement allowed" (per transfer) — e.g. supply caps, country
 *      or balance limits. The token calls `canTransfer` and the state hooks. Part of
 *      the ERC-3643 compliance layer (Module 3). NatSpec authored for RWA-Vault.
 */
interface IModularCompliance {
    /// @notice Emitted when a module function is invoked via {callModuleFunction}.
    event ModuleInteraction(address indexed target, bytes4 selector);

    /// @notice Emitted when a token is bound to this compliance contract.
    event TokenBound(address _token);

    /// @notice Emitted when a token is unbound from this compliance contract.
    event TokenUnbound(address _token);

    /// @notice Emitted when a module is added to the stack.
    event ModuleAdded(address indexed _module);

    /// @notice Emitted when a module is removed from the stack.
    event ModuleRemoved(address indexed _module);

    /// @notice Binds a token to this compliance contract. Callable once, by the token/owner.
    function bindToken(address _token) external;

    /// @notice Unbinds the token from this compliance contract. Owner/token-only.
    function unbindToken(address _token) external;

    /// @notice Adds a transfer-rule module to the stack. Owner-only.
    function addModule(address _module) external;

    /// @notice Removes a transfer-rule module from the stack. Owner-only.
    function removeModule(address _module) external;

    /**
     * @notice Calls a function on a bound module through this compliance contract,
     *         so the module recognises the caller as its bound compliance. Owner-only.
     */
    function callModuleFunction(bytes calldata callData, address _module) external;

    /**
     * @notice Hook called by the token after a transfer so modules can update state.
     * @param _from sender.
     * @param _to receiver.
     * @param _amount amount transferred.
     */
    function transferred(address _from, address _to, uint256 _amount) external;

    /// @notice Hook called by the token after a mint so modules can update state.
    function created(address _to, uint256 _amount) external;

    /// @notice Hook called by the token after a burn so modules can update state.
    function destroyed(address _from, uint256 _amount) external;

    /**
     * @notice Returns true only if every bound module permits the transfer.
     * @param _from sender.
     * @param _to receiver.
     * @param _amount amount to transfer.
     */
    function canTransfer(address _from, address _to, uint256 _amount) external view returns (bool);

    /// @notice Returns the modules currently bound to this compliance contract.
    function getModules() external view returns (address[] memory);

    /// @notice Returns the token bound to this compliance contract.
    function getTokenBound() external view returns (address);

    /// @notice Returns true if the given module is bound.
    function isModuleBound(address _module) external view returns (bool);
}
