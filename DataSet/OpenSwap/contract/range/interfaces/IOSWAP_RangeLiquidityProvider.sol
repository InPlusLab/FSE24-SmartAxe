// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

interface IOSWAP_RangeLiquidityProvider {

    function factory() external view returns (address);
    function WETH() external view returns (address);
    function govToken() external view returns (address);

    // **** ADD LIQUIDITY ****
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool addingTokenA,
        uint256 staked,
        uint256 amountIn,
        uint256 lowerLimit,
        uint256 upperLimit,
        uint256 startDate,
        uint256 expire,
        uint256 deadline
    ) external returns (uint256 index);
    function addLiquidityETH(
        address tokenA,
        bool addingTokenA,
        uint256 staked,
        uint256 amountAIn,
        uint256 lowerLimit,
        uint256 upperLimit,
        uint256 startDate,
        uint256 expire,
        uint256 deadline
    ) external payable returns (uint256 index);

    function updateProviderOffer(
        address tokenA, 
        address tokenB, 
        uint256 replenishAmount, 
        uint256 lowerLimit, 
        uint256 upperLimit, 
        uint256 startDate,
        uint256 expire, 
        bool privateReplenish, 
        uint256 deadline
    ) external;

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool removingTokenA,
        address to,
        uint256 unstake,
        uint256 amountOut,
        uint256 reserveOut,
        uint256 lowerLimit,
        uint256 upperLimit,
        uint256 startDate,
        uint256 expire,
        uint256 deadline
    ) external;
    function removeLiquidityETH(
        address tokenA,
        bool removingTokenA,
        address to,
        uint256 unstake,
        uint256 amountOut,
        uint256 reserveOut,
        uint256 lowerLimit,
        uint256 upperLimit,
        uint256 startDate,
        uint256 expire,
        uint256 deadline
    ) external;
    function removeAllLiquidity(
        address tokenA,
        address tokenB,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
    function removeAllLiquidityETH(
        address tokenA,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);
}
