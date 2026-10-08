// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IModule
 * @notice A pluggable transfer-rule used by the modular compliance contract.
 * @dev Each module encodes one rule (e.g. max balance, country restriction,
 *      supply cap). The compliance contract consults every bound module on
 *      `moduleCheck` and notifies them of state changes. Part of the ERC-3643
 *      compliance layer (Module 3). NatSpec authored for RWA-Vault.
 */
interface IModule {
    /// @notice Emitted when the module is bound to a compliance contract.
    event ComplianceBound(address indexed _compliance);

    /// @notice Emitted when the module is unbound from a compliance contract.
    event ComplianceUnbound(address indexed _compliance);

    /// @notice Binds this module to the calling compliance contract.
    function bindCompliance(address _compliance) external;

    /// @notice Unbinds this module from the calling compliance contract.
    function unbindCompliance(address _compliance) external;

    /// @notice Hook invoked after a compliant transfer so the module can update state.
    function moduleTransferAction(address _from, address _to, uint256 _value) external;

    /// @notice Hook invoked after a mint so the module can update state.
    function moduleMintAction(address _to, uint256 _value) external;

    /// @notice Hook invoked after a burn so the module can update state.
    function moduleBurnAction(address _from, uint256 _value) external;

    /**
     * @notice Returns true if the proposed transfer complies with this module's rule.
     * @param _compliance the compliance contract asking (modules can be multi-bound).
     */
    function moduleCheck(address _from, address _to, uint256 _value, address _compliance) external view returns (bool);

    /// @notice Returns true if this module is bound to the given compliance contract.
    function isComplianceBound(address _compliance) external view returns (bool);

    /// @notice Returns true if this module can be bound to the given compliance contract.
    function canComplianceBind(address _compliance) external view returns (bool);

    /// @notice Returns true if the module needs no per-compliance initialisation to work.
    function isPlugAndPlay() external pure returns (bool);

    /// @notice Returns the module's human-readable name.
    function name() external pure returns (string memory _name);
}
