// src/migrator/USLMigrator.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ILendingMarket, MarketParams} from "../interfaces/ILendingMarket.sol";
import {EVCUtil} from "lib/ethereum-vault-connector/src/utils/EVCUtil.sol";

contract USLMigrator is EVCUtil {
    ILendingMarket immutable lendingMarket;

    constructor(address _evc, address _lendingMarket) EVCUtil(_evc) {
        lendingMarket = ILendingMarket(_lendingMarket);
    }

    function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address receiver)
        external
        onlyEVCAccountOwner
        returns (uint256 assetsBorrowed, uint256 sharesBorrowed)
    {
        return lendingMarket.borrow(marketParams, assets, shares, _msgSender(), receiver);
    }
}
