// src/lending_market/USLLendingMarket.sol

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.30;

import {Id, Market, MarketConstants, MarketParams} from "../interfaces/ILendingMarket.sol";
import {IUsd0PP} from "../interfaces/IUsd0PP.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {MarketParamsLib} from "../libraries/MarketParamsLib.sol";
import {LendingMarket} from "./LendingMarket.sol";

contract USLLendingMarket is LendingMarket {
    using MarketParamsLib for MarketParams;

    constructor(address owner_) LendingMarket(owner_) {}

    function createMarket(MarketParams memory marketParams, MarketConstants memory constants)
        external
        override
        onlyOwner
    {
        _createMarket(marketParams, constants);
    }

    /// @notice Liquidates a borrower's entire position when the USD0++ token has reached maturity
    /// @param marketParams The market parameters
    /// @param borrower The borrower to liquidate
    /// @param data Additional data for the callback
    /// @return seizedAssets The amount of collateral seized
    /// @return repaidAssets The amount of loan token repaid
    function liquidateExpiredUSL(MarketParams memory marketParams, address borrower, bytes calldata data)
        external
        onlyUslLiquidator
        returns (uint256 seizedAssets, uint256 repaidAssets)
    {
        Id id = marketParams.id();
        Market storage market_ = market[id];
        require(market_.lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);

        require(
            block.timestamp
                >= IUsd0PP(marketParams.collateralToken).getEndTime() + marketConstants[id].maturityGracePeriod,
            ErrorsLib.USL_NOT_EXPIRED
        );

        return _liquidatePostMaturity(market_, marketParams, id, borrower, data);
    }
}
