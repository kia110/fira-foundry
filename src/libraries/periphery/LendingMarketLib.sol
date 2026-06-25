// src/libraries/periphery/LendingMarketLib.sol

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ILendingMarket, Id} from "../../interfaces/ILendingMarket.sol";
import {LendingMarketStorageLib} from "./LendingMarketStorageLib.sol";

/// @title LMLib
/// @author Fira Labs
/// @notice Helper library to access LM storage variables.
/// @dev Warning: Supply and borrow getters may return outdated values that do not include accrued
/// interest.
library LendingMarketLib {
    function supplyShares(ILendingMarket lendingMarket, Id id, address user) internal view returns (uint256) {
        bytes32[] memory slot = _array(LendingMarketStorageLib.positionSupplySharesSlot(id, user));
        return uint256(lendingMarket.extSloads(slot)[0]);
    }

    function borrowShares(ILendingMarket lendingMarket, Id id, address user) internal view returns (uint256) {
        bytes32[] memory slot = _array(LendingMarketStorageLib.positionBorrowSharesAndCollateralSlot(id, user));
        return uint128(uint256(lendingMarket.extSloads(slot)[0]));
    }

    function collateral(ILendingMarket lendingMarket, Id id, address user) internal view returns (uint256) {
        bytes32[] memory slot = _array(LendingMarketStorageLib.positionBorrowSharesAndCollateralSlot(id, user));
        return uint256(lendingMarket.extSloads(slot)[0] >> 128);
    }

    function totalSupplyAssets(ILendingMarket lendingMarket, Id id) internal view returns (uint256) {
        bytes32[] memory slot = _array(LendingMarketStorageLib.marketTotalSupplyAssetsAndSharesSlot(id));
        return uint128(uint256(lendingMarket.extSloads(slot)[0]));
    }

    function totalSupplyShares(ILendingMarket lendingMarket, Id id) internal view returns (uint256) {
        bytes32[] memory slot = _array(LendingMarketStorageLib.marketTotalSupplyAssetsAndSharesSlot(id));
        return uint256(lendingMarket.extSloads(slot)[0] >> 128);
    }

    function totalBorrowAssets(ILendingMarket lendingMarket, Id id) internal view returns (uint256) {
        bytes32[] memory slot = _array(LendingMarketStorageLib.marketTotalBorrowAssetsAndSharesSlot(id));
        return uint128(uint256(lendingMarket.extSloads(slot)[0]));
    }

    function totalBorrowShares(ILendingMarket lendingMarket, Id id) internal view returns (uint256) {
        bytes32[] memory slot = _array(LendingMarketStorageLib.marketTotalBorrowAssetsAndSharesSlot(id));
        return uint256(lendingMarket.extSloads(slot)[0] >> 128);
    }

    function lastUpdate(ILendingMarket lendingMarket, Id id) internal view returns (uint256) {
        bytes32[] memory slot = _array(LendingMarketStorageLib.marketLastUpdateAndFeeSlot(id));
        return uint128(uint256(lendingMarket.extSloads(slot)[0]));
    }

    function fee(ILendingMarket lendingMarket, Id id) internal view returns (uint256) {
        bytes32[] memory slot = _array(LendingMarketStorageLib.marketLastUpdateAndFeeSlot(id));
        return uint256(lendingMarket.extSloads(slot)[0] >> 128);
    }

    function _array(bytes32 x) private pure returns (bytes32[] memory) {
        bytes32[] memory res = new bytes32[](1);
        res[0] = x;
        return res;
    }
}
