// src/sisu_vault/PermissionedSisuVault.sol

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.30;

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {SisuVault} from "./SisuVault.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title PermissionedSisuVault
/// @author Fira Labs
/// @notice ERC4626 compliant vault that allow only permissioned user to deposit/withdraw
contract PermissionedSisuVault is SisuVault {
    address public permissionedAddress;

    modifier onlyPermissioned() {
        if (msg.sender != permissionedAddress) revert ErrorsLib.Unauthorized();
        _;
    }

    /// @notice Emitted when the permissioned address is updated
    event SetPermissionedAddress(address indexed newPermissionedAddress);

    constructor(
        address owner,
        address lendingMarket,
        uint256 initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol
    ) SisuVault(owner, lendingMarket, initialTimelock, _asset, _name, _symbol) {}

    /// @notice Sets the permissioned address that can access erc4626 functions
    /// @param _permissionedAddress The new permissioned address.
    function setPermissionedAddress(address _permissionedAddress) external onlyOwner {
        if (_permissionedAddress == address(0)) revert ErrorsLib.ZeroAddress();
        permissionedAddress = _permissionedAddress;
        emit SetPermissionedAddress(_permissionedAddress);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) public override onlyPermissioned returns (uint256 shares) {
        return super.deposit(assets, receiver);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public override onlyPermissioned returns (uint256 assets) {
        return super.mint(shares, receiver);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        onlyPermissioned
        returns (uint256 shares)
    {
        return super.withdraw(assets, receiver, owner);
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        onlyPermissioned
        returns (uint256 assets)
    {
        return super.redeem(shares, receiver, owner);
    }
}
