// src/sisu_vault/PermissionedSisuVaultFactory.sol

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.30;

import {IPermissionedSisuVaultFactory} from "../interfaces/IPermissionedSisuVaultFactory.sol";
import {IPermissionedSisuVault} from "../interfaces/ISisuVault.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {EventsLib} from "../libraries/EventsLib.sol";

import {PermissionedSisuVault} from "./PermissionedSisuVault.sol";

/// @title PermissionedSisuVaultFactory
/// @author Fira Labs
/// @notice @notice This contract allows to create Permissioned Sisu vaults, and to index them easily.
contract PermissionedSisuVaultFactory is IPermissionedSisuVaultFactory {
    /* IMMUTABLES */

    /// @inheritdoc IPermissionedSisuVaultFactory
    address public immutable LENDING_MARKET;

    /* STORAGE */

    /// @inheritdoc IPermissionedSisuVaultFactory
    mapping(address => bool) public isSisuVault;

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param lendingMarket The address of the LM contract.
    constructor(address lendingMarket) {
        if (lendingMarket == address(0)) revert ErrorsLib.ZeroAddress();

        LENDING_MARKET = lendingMarket;
    }

    /* EXTERNAL */

    /// @inheritdoc IPermissionedSisuVaultFactory
    function createPermissionedSisuVault(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (IPermissionedSisuVault permissionedSisuVault) {
        permissionedSisuVault = IPermissionedSisuVault(
            address(
                new PermissionedSisuVault{
                    salt: salt
                }(initialOwner, LENDING_MARKET, initialTimelock, asset, name, symbol)
            )
        );

        isSisuVault[address(permissionedSisuVault)] = true;

        emit EventsLib.CreateSisuVault(
            address(permissionedSisuVault), msg.sender, initialOwner, initialTimelock, asset, name, symbol, salt
        );
    }
}
