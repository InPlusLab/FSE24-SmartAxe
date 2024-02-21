// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../../commons/interfaces/IOSWAP_PausablePair.sol';

interface IOSWAP_RestrictedPair is IOSWAP_PausablePair {

    struct Offer {
        address provider;
        bool locked;
        bool allowAll;
        uint256 amount;
        uint256 receiving;
        uint256 restrictedPrice;
        uint256 startDate;
        uint256 expire;
    } 

    event NewProviderOffer(address indexed provider, bool indexed direction, uint256 index, bool allowAll, uint256 restrictedPrice, uint256 startDate, uint256 expire);
    // event AddLiquidity(address indexed provider, bool indexed direction, uint256 indexed index, uint256 amount, uint256 newAmountBalance);
    event Lock(bool indexed direction, uint256 indexed index);
    // event RemoveLiquidity(address indexed provider, bool indexed direction, uint256 indexed index, uint256 amountOut, uint256 receivingOut, uint256 newAmountBalance, uint256 newReceivingBalance);
    event Swap(address indexed to, bool indexed direction, uint256 amountIn, uint256 amountOut, uint256 tradeFee, uint256 protocolFee);
    event SwappedOneOffer(address indexed provider, bool indexed direction, uint256 indexed index, uint256 price, uint256 amountOut, uint256 amountIn, uint256 newAmountBalance, uint256 newReceivingBalance);

    event ApprovedTrader(bool indexed direction, uint256 indexed offerIndex, address indexed trader, uint256 allocation);

    function counter(bool direction) external view returns (uint256);
    function offers(bool direction, uint256 i) external view returns (
        address provider,
        bool locked,
        bool allowAll,
        uint256 amount,
        uint256 receiving,
        uint256 restrictedPrice,
        uint256 startDate,
        uint256 expire
    );

    function providerOfferIndex(bool direction, address provider, uint256 i) external view returns (uint256 index);
    function approvedTrader(bool direction, uint256 offerIndex, uint256 i) external view returns (address trader);
    function isApprovedTrader(bool direction, uint256 offerIndex, address trader) external view returns (bool);
    function traderAllocation(bool direction, uint256 offerIndex, address trader) external view returns (uint256 amount);
    function traderOffer(bool direction, address trader, uint256 i) external view returns (uint256 index);

    function governance() external view returns (address);
    function whitelistFactory() external view returns (address);
    function restrictedLiquidityProvider() external view returns (address);
    function govToken() external view returns (address);
    function configStore() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function scaleDirection() external view returns (bool);
    function scaler() external view returns (uint256);

    function lastGovBalance() external view returns (uint256);
    function lastToken0Balance() external view returns (uint256);
    function lastToken1Balance() external view returns (uint256);
    function protocolFeeBalance0() external view returns (uint256);
    function protocolFeeBalance1() external view returns (uint256);
    function feeBalance() external view returns (uint256);

    function initialize(address _token0, address _token1) external;

    function getProviderOfferIndexLength(address provider, bool direction) external view returns (uint256);
    function getTraderOffer(address trader, bool direction, uint256 start, uint256 length) external view returns (uint256[] memory index, address[] memory provider, bool[] memory lockedAndAllowAll, uint256[] memory receiving, uint256[] memory amountAndPrice, uint256[] memory startDateAndExpire);
    function getProviderOffer(address _provider, bool direction, uint256 start, uint256 length) external view returns (uint256[] memory index, address[] memory provider, bool[] memory lockedAndAllowAll, uint256[] memory receiving, uint256[] memory amountAndPrice, uint256[] memory startDateAndExpire);
    function getApprovedTraderLength(bool direction, uint256 offerIndex) external view returns (uint256);
    function getApprovedTrader(bool direction, uint256 offerIndex, uint256 start, uint256 end) external view returns (address[] memory traders, uint256[] memory allocation);

    function getOffers(bool direction, uint256 start, uint256 length) external view returns (uint256[] memory index, address[] memory provider, bool[] memory lockedAndAllowAll, uint256[] memory receiving, uint256[] memory amountAndPrice, uint256[] memory startDateAndExpire);

    function getLastBalances() external view returns (uint256, uint256);
    function getBalances() external view returns (uint256, uint256, uint256);

    function getAmountOut(address tokenIn, uint256 amountIn, address trader, bytes calldata data) external view returns (uint256 amountOut);
    function getAmountIn(address tokenOut, uint256 amountOut, address trader, bytes calldata data) external view returns (uint256 amountIn);

    function createOrder(address provider, bool direction, bool allowAll, uint256 restrictedPrice, uint256 startDate, uint256 expire) external returns (uint256 index);
    // function addLiquidity(bool direction, uint256 index) external;
    function lockOffer(bool direction, uint256 index) external;
    // function removeLiquidity(address provider, bool direction, uint256 index, uint256 amountOut, uint256 receivingOut) external;
    // function removeAllLiquidity(address provider) external returns (uint256 amount0, uint256 amount1);
    // function removeAllLiquidity1D(address provider, bool direction) external returns (uint256 totalAmount, uint256 totalReceiving);

    // function setApprovedTrader(bool direction, uint256 offerIndex, address trader, uint256 allocation) external;
    // function setMultipleApprovedTraders(bool direction, uint256 offerIndex, address[] calldata trader, uint256[] calldata allocation) external;

    function swap(uint256 amount0Out, uint256 amount1Out, address to, address trader, bytes calldata data) external;

    function sync() external;

    function redeemProtocolFee() external;
}