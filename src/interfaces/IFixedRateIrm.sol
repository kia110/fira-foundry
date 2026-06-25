// src/interfaces/IFixedRateIrm.sol

// // SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.30;

import {IIrm} from "./IIrm.sol";
import {Id} from "./ILendingMarket.sol";

/// @title IFixedRateIrm
/// @author Fira Labs
interface IFixedRateIrm is IIrm {
    /* EVENTS */

    /// @notice Emitted when a borrow rate is set.
    event SetBorrowRate(Id indexed id, uint256 newBorrowRate);

    /* EXTERNAL */

    /// @notice Max settable borrow rate (800%).
    function MAX_BORROW_RATE() external returns (uint256);

    /// @notice Borrow rates.
    function borrowRateStored(Id id) external returns (uint256);

    /// @notice Sets the borrow rate for a market.
    /// @dev A rate can be set by anybody, but only once.
    /// @dev `borrowRate` reverts on rate not set, so the rate needs to be set before the market creation.
    /// @dev As interest are rounded down in LendingMarket, for markets with a low total borrow, setting a rate too low
    /// could
    /// prevent interest from accruing if interactions are frequent.
    function setBorrowRate(Id id, uint256 newBorrowRate) external;
}
