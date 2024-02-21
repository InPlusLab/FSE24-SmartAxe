// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../../commons/interfaces/IOSWAP_PausablePair.sol';

interface IOSWAP_RangePair is IOSWAP_PausablePair {

    struct Offer {
        address provider;
        uint256 amount;
        uint256 reserve;
        uint256 lowerLimit;
        uint256 upperLimit;
        uint256 startDate;
        uint256 expire;
        bool privateReplenish;
    } 

    event NewProvider(address indexed provider, uint256 index);
    event AddLiquidity(address indexed provider, bool indexed direction, uint256 staked, uint256 amount, uint256 newStakeBalance, uint256 newAmountBalance, uint256 lowerLimit, uint256 upperLimit, uint256 startDate, uint256 expire);
    event Replenish(address indexed provider, bool indexed direction, uint256 amountIn, uint256 newAmountBalance, uint256 newReserveBalance);
    event UpdateProviderOffer(address indexed provider, bool indexed direction, uint256 replenish, uint256 newAmountBalance, uint256 newReserveBalance, uint256 lowerLimit, uint256 upperLimit, uint256 startDate, uint256 expire, bool privateReplenish);
    event RemoveLiquidity(address indexed provider, bool indexed direction, uint256 unstake, uint256 amountOut, uint256 reserveOut, uint256 newStakeBalance, uint256 newAmountBalance, uint256 newReserveBalance, uint256 lowerLimit, uint256 upperLimit, uint256 startDate, uint256 expire);
    event RemoveAllLiquidity(address indexed provider, uint256 unstake, uint256 amount0Out, uint256 amount1Out);
    event Swap(address indexed to, bool indexed direction, uint256 price, uint256 amountIn, uint256 amountOut, uint256 tradeFee, uint256 protocolFee);
    event SwappedOneProvider(address indexed provider, bool indexed direction, uint256 amountOut, uint256 amountIn, uint256 newAmountBalance, uint256 newCounterReserveBalance);

    function counter() external view returns (uint256);
    function offers(bool direction, uint256 index) external view returns (
        address provider,
        uint256 amount,
        uint256 reserve,
        uint256 lowerLimit,
        uint256 upperLimit,
        uint256 startDate,
        uint256 expire,
        bool privateReplenish
    );
    function providerOfferIndex(address provider) external view returns (uint256 index);
    function providerStaking(address provider) external view returns (uint256 stake);

    function oracleFactory() external view returns (address);
    function governance() external view returns (address);
    function rangeLiquidityProvider() external view returns (address);
    function govToken() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function scaleDirection() external view returns (bool);
    function scaler() external view returns (uint256);

    function lastGovBalance() external view returns (uint256);
    function lastToken0Balance() external view returns (uint256);
    function lastToken1Balance() external view returns (uint256);
    function protocolFeeBalance0() external view returns (uint256);
    function protocolFeeBalance1() external view returns (uint256);
    function stakeBalance() external view returns (uint256);

    function initialize(address _token0, address _token1) external;

    function getOffers(bool direction, uint256 start, uint256 end) external view returns (address[] memory provider, uint256[] memory amountAndReserve, uint256[] memory lowerLimitAndUpperLimit, uint256[] memory startDateAndExpire, bool[] memory privateReplenish);
    function getLastBalances() external view returns (uint256, uint256);
    function getBalances() external view returns (uint256, uint256, uint256);

    function getLatestPrice(bool direction, bytes calldata payload) external view returns (uint256);
    function getAmountOut(address tokenIn, uint256 amountIn, bytes calldata data) external view returns (uint256 amountOut);
    function getAmountIn(address tokenOut, uint256 amountOut, bytes calldata data) external view returns (uint256 amountIn);

    function getProviderOffer(address provider, bool direction) external view returns (uint256 index, uint256 staked, uint256 amount, uint256 reserve, uint256 lowerLimit, uint256 upperLimit, uint256 startDate, uint256 expire, bool privateReplenish);
    function addLiquidity(address provider, bool direction, uint256 staked, uint256 _lowerLimit, uint256 _upperLimit, uint256 startDate, uint256 expire) external returns (uint256 index);
    function updateProviderOffer(address provider, bool direction, uint256 replenish, uint256 lowerLimit, uint256 upperLimit, uint256 startDate, uint256 expire, bool privateReplenish) external;
    function replenish(address provider, bool direction, uint256 amountIn) external;
    function removeLiquidity(address provider, bool direction, uint256 unstake, uint256 amountOut, uint256 reserveOut, uint256 lowerLimit, uint256 upperLimit, uint256 startDate, uint256 expire) external;
    function removeAllLiquidity(address provider) external returns (uint256 amount0, uint256 amount1, uint256 staked);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function sync() external;

    function redeemProtocolFee() external;
}