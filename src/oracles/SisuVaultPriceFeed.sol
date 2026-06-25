// src/oracles/SisuVaultPriceFeed.sol

// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.30;

import {IERC4626} from "../interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title  SisuVault Price Per Share Feed (Chainlink-compatible)
 * @notice Chainlink AggregatorV3Interface-compatible feed that returns the ERC4626 vault price per share
 *         (amount of underlying assets per 1 share) for a given SisuVault.
 * @dev    `answer` is denominated with the underlying asset decimals; `decimals()` returns the underlying
 *         asset decimals. The round id is set to the current block timestamp for compatibility.
 */
contract SisuVaultPriceFeed {
    IERC4626 public immutable VAULT;
    IERC20Metadata public immutable ASSET;
    uint8 public immutable ANSWER_DECIMALS;
    uint256 public immutable FLOOR;

    /// @param vault The address of the ERC4626 SisuVault to read the price per share from.
    constructor(address vault) {
        VAULT = IERC4626(vault);
        ASSET = IERC20Metadata(IERC4626(vault).asset());
        ANSWER_DECIMALS = ASSET.decimals();
        FLOOR = 10 ** uint256(ANSWER_DECIMALS);
    }

    /// @notice Returns the number of decimals used in price feed output (underlying asset decimals).
    function decimals() public view virtual returns (uint8) {
        return ANSWER_DECIMALS;
    }

    /// @notice Returns the description of the price feed.
    function description() public pure returns (string memory) {
        return "SisuVault Price Per Share";
    }

    /// @notice Returns the version of the price feed.
    function version() public pure returns (uint256) {
        return 1;
    }

    /// @notice Returns the round data for a given round ID.
    /// @param _roundId The round ID.
    /// @return roundId The round ID.
    /// @return answer The price per share.
    /// @return startedAt The timestamp when the round started.
    /// @return updatedAt The timestamp when the round was last updated.
    /// @return answeredInRound The round ID in which the answer was computed.
    /// @dev The round ID is set to the current block timestamp for compatibility.
    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        int256 pps = _pricePerShare();
        uint256 ts = block.timestamp;
        return (_roundId, pps, ts, ts, _roundId);
    }

    /// @notice Returns the latest round data.
    /// @return roundId The round ID.
    /// @return answer The price per share.
    /// @return startedAt The timestamp when the round started.
    /// @return updatedAt The timestamp when the round was last updated.
    /// @return answeredInRound The round ID in which the answer was computed.
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = uint80(block.timestamp);
        return (roundId, _pricePerShare(), block.timestamp, block.timestamp, roundId);
    }

    /// @notice Computes price per 1 share in units of underlying assets (with underlying decimals).
    /// @return The price per share.
    function _pricePerShare() internal view returns (int256) {
        uint256 oneShare = 10 ** uint256(VAULT.decimals());
        uint256 assets = VAULT.convertToAssets(oneShare);
        if (assets < FLOOR) {
            return int256(FLOOR);
        }
        return int256(assets);
    }
}
