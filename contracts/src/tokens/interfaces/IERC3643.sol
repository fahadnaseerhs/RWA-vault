// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../registry/interfaces/IIdentityRegistry.sol";
import "../../compliance/interfaces/IModularCompliance.sol";

/**
 * @title IERC3643 — Permissioned RWA Token
 * @notice An ERC-20 whose every mint and transfer is gated by an Identity Registry
 *         (who may hold) and a Modular Compliance contract (is this movement allowed).
 * @dev This is the tokenised real-world asset in RWA-Vault (Module 3, Registry):
 *      only verified wallets can receive it, agents can freeze wallets or partial
 *      balances, force transfers for legal/recovery reasons, and recover tokens from
 *      a lost wallet to a new one. Implements the EIP-3643 standard. NatSpec authored
 *      for RWA-Vault; signatures follow EIP-3643 (https://eips.ethereum.org/EIPS/eip-3643).
 */
interface IERC3643 is IERC20 {
    // ------------------------------------------------------------------ events

    /// @notice Emitted when the token's name/symbol/decimals/version/onchainID change.
    event UpdatedTokenInformation(
        string indexed _newName,
        string indexed _newSymbol,
        uint8 _newDecimals,
        string _newVersion,
        address indexed _newOnchainID
    );

    /// @notice Emitted when the Identity Registry is set for the token.
    event IdentityRegistryAdded(address indexed _identityRegistry);

    /// @notice Emitted when the Compliance contract is set for the token.
    event ComplianceAdded(address indexed _compliance);

    /// @notice Emitted when an investor recovers tokens from a lost wallet to a new one.
    event RecoverySuccess(address indexed _lostWallet, address indexed _newWallet, address indexed _investorOnchainID);

    /// @notice Emitted when a wallet is frozen or unfrozen.
    event AddressFrozen(address indexed _userAddress, bool indexed _isFrozen, address indexed _owner);

    /// @notice Emitted when an amount of tokens is partially frozen on a wallet.
    event TokensFrozen(address indexed _userAddress, uint256 _amount);

    /// @notice Emitted when an amount of tokens is partially unfrozen on a wallet.
    event TokensUnfrozen(address indexed _userAddress, uint256 _amount);

    /// @notice Emitted when the token is paused.
    event Paused(address _userAddress);

    /// @notice Emitted when the token is unpaused.
    event Unpaused(address _userAddress);

    // ------------------------------------------------------------- admin config

    /// @notice Sets the token name. Owner-only. Emits {UpdatedTokenInformation}.
    function setName(string calldata _name) external;

    /// @notice Sets the token symbol. Owner-only. Emits {UpdatedTokenInformation}.
    function setSymbol(string calldata _symbol) external;

    /// @notice Sets the token's onchainID. Owner-only. Emits {UpdatedTokenInformation}.
    function setOnchainID(address _onchainID) external;

    /// @notice Sets the Identity Registry. Owner-only. Emits {IdentityRegistryAdded}.
    function setIdentityRegistry(address _identityRegistry) external;

    /// @notice Sets the Compliance contract (and binds the token to it). Owner-only.
    function setCompliance(address _compliance) external;

    // -------------------------------------------------------------- freeze/pause

    /// @notice Pauses all transfers. Agent-only. Emits {Paused}.
    function pause() external;

    /// @notice Resumes transfers. Agent-only. Emits {Unpaused}.
    function unpause() external;

    /// @notice Freezes or unfreezes a wallet entirely. Agent-only. Emits {AddressFrozen}.
    function setAddressFrozen(address _userAddress, bool _freeze) external;

    /// @notice Freezes a partial token amount on a wallet. Agent-only. Emits {TokensFrozen}.
    function freezePartialTokens(address _userAddress, uint256 _amount) external;

    /// @notice Unfreezes a partial token amount on a wallet. Agent-only. Emits {TokensUnfrozen}.
    function unfreezePartialTokens(address _userAddress, uint256 _amount) external;

    // --------------------------------------------------------- supply & recovery

    /**
     * @notice Forces a transfer between two wallets, drawing on frozen balance if
     *         needed. Requires `_to` to be verified. Agent-only.
     * @return true on success (reverts otherwise).
     */
    function forcedTransfer(address _from, address _to, uint256 _amount) external returns (bool);

    /// @notice Mints tokens to a verified wallet. Agent-only. Emits {Transfer}.
    function mint(address _to, uint256 _amount) external;

    /// @notice Burns tokens from a wallet, drawing on frozen balance if needed. Agent-only.
    function burn(address _userAddress, uint256 _amount) external;

    /**
     * @notice Recovers tokens from a lost wallet to a new wallet belonging to the
     *         same investor identity. Agent-only. Emits {RecoverySuccess} on success.
     */
    function recoveryAddress(address _lostWallet, address _newWallet, address _investorOnchainID)
        external
        returns (bool);

    // ----------------------------------------------------------------- batching

    /// @notice Batch form of {transfer}.
    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) external;

    /// @notice Batch form of {forcedTransfer}. Agent-only.
    function batchForcedTransfer(address[] calldata _fromList, address[] calldata _toList, uint256[] calldata _amounts)
        external;

    /// @notice Batch form of {mint}. Agent-only.
    function batchMint(address[] calldata _toList, uint256[] calldata _amounts) external;

    /// @notice Batch form of {burn}. Agent-only.
    function batchBurn(address[] calldata _userAddresses, uint256[] calldata _amounts) external;

    /// @notice Batch form of {setAddressFrozen}. Agent-only.
    function batchSetAddressFrozen(address[] calldata _userAddresses, bool[] calldata _freeze) external;

    /// @notice Batch form of {freezePartialTokens}. Agent-only.
    function batchFreezePartialTokens(address[] calldata _userAddresses, uint256[] calldata _amounts) external;

    /// @notice Batch form of {unfreezePartialTokens}. Agent-only.
    function batchUnfreezePartialTokens(address[] calldata _userAddresses, uint256[] calldata _amounts) external;

    // -------------------------------------------------------------------- views

    /// @notice Returns the number of decimals used for display.
    function decimals() external view returns (uint8);

    /// @notice Returns the token name.
    function name() external view returns (string memory);

    /// @notice Returns the token symbol.
    function symbol() external view returns (string memory);

    /// @notice Returns the token's onchainID address.
    function onchainID() external view returns (address);

    /// @notice Returns the ERC-3643 implementation version string.
    function version() external view returns (string memory);

    /// @notice Returns the Identity Registry linked to the token.
    function identityRegistry() external view returns (IIdentityRegistry);

    /// @notice Returns the Compliance contract linked to the token.
    function compliance() external view returns (IModularCompliance);

    /// @notice Returns true if the token is paused.
    function paused() external view returns (bool);

    /// @notice Returns the full-freeze status of a wallet.
    function isFrozen(address _userAddress) external view returns (bool);

    /// @notice Returns the partially-frozen token amount on a wallet.
    function getFrozenTokens(address _userAddress) external view returns (uint256);
}
