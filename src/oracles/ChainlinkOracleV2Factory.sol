// src/oracles/ChainlinkOracleV2Factory.sol

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.30;

import {IChainlinkOracleV2} from "../interfaces/IChainlinkOracleV2.sol";
import {IChainlinkOracleV2Factory} from "../interfaces/IChainlinkOracleV2Factory.sol";
import {AggregatorV3Interface} from "../libraries/ChainlinkDataFeedLib.sol";
import {IERC4626} from "../libraries/VaultLib.sol";

import {ChainlinkOracleV2} from "./ChainlinkOracleV2.sol";

/// @title ChainlinkOracleV2Factory
/// @author Fira Labs
/// @notice This contract allows to create ChainlinkOracleV2 oracles, and to index them
/// easily.
contract ChainlinkOracleV2Factory is IChainlinkOracleV2Factory {
    /* STORAGE */

    /// @inheritdoc IChainlinkOracleV2Factory
    mapping(address => bool) public isChainlinkOracleV2;

    /* EXTERNAL */

    /// @inheritdoc IChainlinkOracleV2Factory
    function createChainlinkOracleV2(
        IERC4626 baseVault,
        uint256 baseVaultConversionSample,
        AggregatorV3Interface baseFeed1,
        AggregatorV3Interface baseFeed2,
        uint256 baseTokenDecimals,
        IERC4626 quoteVault,
        uint256 quoteVaultConversionSample,
        AggregatorV3Interface quoteFeed1,
        AggregatorV3Interface quoteFeed2,
        uint256 quoteTokenDecimals,
        bytes32 salt
    ) external returns (IChainlinkOracleV2 oracle) {
        oracle = new ChainlinkOracleV2{
            salt: salt
        }(
            baseVault,
            baseVaultConversionSample,
            baseFeed1,
            baseFeed2,
            baseTokenDecimals,
            quoteVault,
            quoteVaultConversionSample,
            quoteFeed1,
            quoteFeed2,
            quoteTokenDecimals
        );

        isChainlinkOracleV2[address(oracle)] = true;

        emit CreateChainlinkOracleV2(msg.sender, address(oracle));
    }
}
