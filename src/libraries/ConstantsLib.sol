// src/libraries/ConstantsLib.sol

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.30;

/// @dev The maximum fee a market can have (25%).
uint256 constant MAX_FEE = 0.25e18;

/// @dev Oracle price scale.
uint256 constant ORACLE_PRICE_SCALE = 1e36;

/// @dev Liquidation cursor.
uint256 constant LIQUIDATION_CURSOR = 0.3e18;

/// @dev Max liquidation incentive factor.
uint256 constant MAX_LIQUIDATION_INCENTIVE_FACTOR = 1.15e18;

/// @dev The EIP-712 typeHash for EIP712Domain.
bytes32 constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");

/// @dev The EIP-712 typeHash for Authorization.
bytes32 constant AUTHORIZATION_TYPEHASH =
    keccak256("Authorization(address authorizer,address authorized,bool isAuthorized,uint256 nonce,uint256 deadline)");

/// @dev The maximum delay of a timelock.
uint256 constant MAX_TIMELOCK = 2 weeks;

/// @dev The minimum delay of a timelock.
uint256 constant MIN_TIMELOCK = 0.1 days;

/// @dev The maximum number of markets in the supply/withdraw queue.
uint256 constant MAX_QUEUE_LENGTH = 30;

/// @dev The maximum fee the vault can have (50%).
uint256 constant MAX_VAULT_FEE = 0.5e18;

/// @dev Basis points (100% = 10000 bps).
uint256 constant BIPS = 10000;

/// @dev Curve steepness (scaled by WAD).
/// @dev Curve steepness = 4.
int256 constant CURVE_STEEPNESS = 4 ether;

/// @dev Adjustment speed per second (scaled by WAD).
/// @dev The speed is per second, so the rate moves at a speed of ADJUSTMENT_SPEED * err each second (while being
/// continuously compounded).
/// @dev Adjustment speed = 50/year.
int256 constant ADJUSTMENT_SPEED = 50 ether / int256(365 days);

/// @dev Target utilization (scaled by WAD).
/// @dev Target utilization = 90%.
int256 constant TARGET_UTILIZATION = 0.9 ether;

/// @dev Initial rate at target per second (scaled by WAD).
/// @dev Initial rate at target = 4% (rate between 1% and 16%).
int256 constant INITIAL_RATE_AT_TARGET = 0.04 ether / int256(365 days);

/// @dev Minimum rate at target per second (scaled by WAD).
/// @dev Minimum rate at target = 0.1% (minimum rate = 0.025%).
int256 constant MIN_RATE_AT_TARGET = 0.001 ether / int256(365 days);

/// @dev Maximum rate at target per second (scaled by WAD).
/// @dev Maximum rate at target = 200% (maximum rate = 800%).
int256 constant MAX_RATE_AT_TARGET = 2.0 ether / int256(365 days);

/* Addresses */
address constant USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

address constant WBTC_MAINNET = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

address constant WETH_MAINNET = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
