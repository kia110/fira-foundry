// src/interfaces/ICallbacks.sol

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.30;

/// @title ILiquidateCallback
/// @notice Interface that liquidators willing to use `liquidate`'s callback must implement.
interface ILiquidateCallback {
    /// @notice Callback called when a liquidation occurs.
    /// @dev The callback is called only if data is not empty.
    /// @param repaidAssets The amount of repaid assets.
    /// @param data Arbitrary data passed to the `liquidate` function.
    function onLiquidate(uint256 repaidAssets, bytes calldata data) external;
}

/// @title IRepayCallback
/// @notice Interface that users willing to use `repay`'s callback must implement.
interface IRepayCallback {
    /// @notice Callback called when a repayment occurs.
    /// @dev The callback is called only if data is not empty.
    /// @param assets The amount of repaid assets.
    /// @param data Arbitrary data passed to the `repay` function.
    function onRepay(uint256 assets, bytes calldata data) external;
}

/// @title ISupplyCallback
/// @notice Interface that users willing to use `supply`'s callback must implement.
interface ISupplyCallback {
    /// @notice Callback called when a supply occurs.
    /// @dev The callback is called only if data is not empty.
    /// @param assets The amount of supplied assets.
    /// @param data Arbitrary data passed to the `supply` function.
    function onSupply(uint256 assets, bytes calldata data) external;
}

/// @title ISupplyCollateralCallback
/// @notice Interface that users willing to use `supplyCollateral`'s callback must implement.
interface ISupplyCollateralCallback {
    /// @notice Callback called when a supply of collateral occurs.
    /// @dev The callback is called only if data is not empty.
    /// @param assets The amount of supplied collateral.
    /// @param data Arbitrary data passed to the `supplyCollateral` function.
    function onSupplyCollateral(uint256 assets, bytes calldata data) external;
}

/// @title IFlashLoanCallback
/// @notice Interface that users willing to use `flashLoan`'s callback must implement.
interface IFlashLoanCallback {
    /// @notice Callback called when a flash loan occurs.
    /// @dev The callback is called only if data is not empty.
    /// @param assets The amount of assets that was flash loaned.
    /// @param data Arbitrary data passed to the `flashLoan` function.
    function onFlashLoan(uint256 assets, bytes calldata data) external;
}
