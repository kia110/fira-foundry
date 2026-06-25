// src/interfaces/IPermissionedSisuVaultFactory.sol

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.30;

import {IPermissionedSisuVault} from "./ISisuVault.sol";

/// @title IPermissionedSisuVaultFactory
/// @author Fira Labs
/// @notice Interface of Permissioned Sisu Vault factory.
interface IPermissionedSisuVaultFactory {
    /// @notice The address of the LM contract.
    function LENDING_MARKET() external view returns (address);

    /// @notice Whether a Sisu vault was created with the factory.
    function isSisuVault(address target) external view returns (bool);

    /// @notice Creates a new Permissioned Sisu vault.
    /// @param initialOwner The owner of the vault.
    /// @param initialTimelock The initial timelock of the vault.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the vault.
    /// @param symbol The symbol of the vault.
    /// @param salt The salt to use for the Sisu vault's CREATE2 address.
    function createPermissionedSisuVault(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (IPermissionedSisuVault permissionedSisuVault);
}
