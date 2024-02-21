// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

interface IOSWAP_RestrictedLiquidityProvider1 {
    function factory() external view returns (address);
    function WETH() external view returns (address);
    function govToken() external view returns (address);
    function configStore() external view returns (address);

    // **** ADD LIQUIDITY ****
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool addingTokenA,
        uint256 pairIndex,
        uint256 offerIndex,
        uint256 amountIn,
        bool locked,
        uint256 restrictedPrice,
        uint256 startDate,
        uint256 expire,
        uint256 deadline
    ) external returns (address pair, uint256 _offerIndex);
    function addLiquidityETH(
        address tokenA,
        bool addingTokenA,
        uint256 pairIndex,
        uint256 offerIndex,
        uint256 amountAIn,
        bool locked,
        uint256 restrictedPrice,
        uint256 startDate,
        uint256 expire,
        uint256 deadline
    ) external payable returns (address pair, uint256 _offerIndex);
    function addLiquidityAndTrader(
        uint256[11] calldata param, 
        address[] calldata trader, 
        uint256[] calldata allocation
    ) external returns (address pair, uint256 offerIndex);
    function addLiquidityETHAndTrader(
        uint256[10] calldata param, 
        address[] calldata trader, 
        uint256[] calldata allocation
    ) external payable returns (address pair, uint256 offerIndex);

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool removingTokenA,
        address to,
        uint256 pairIndex,
        uint256 offerIndex,
        uint256 amountOut,
        uint256 receivingOut,
        uint256 deadline
    ) external;
    function removeLiquidityETH(
        address tokenA,
        bool removingTokenA,
        address to,
        uint256 pairIndex,
        uint256 offerIndex,
        uint256 amountOut,
        uint256 receivingOut,
        uint256 deadline
    ) external;
    function removeAllLiquidity(
        address tokenA,
        address tokenB,
        address to,
        uint256 pairIndex,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
    function removeAllLiquidityETH(
        address tokenA,
        address to,
        uint256 pairIndex,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);
}
