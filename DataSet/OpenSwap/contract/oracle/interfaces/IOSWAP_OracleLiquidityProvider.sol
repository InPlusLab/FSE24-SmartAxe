// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

interface IOSWAP_OracleLiquidityProvider {

    function factory() external view returns (address);
    function WETH() external view returns (address);
    function govToken() external view returns (address);

    // **** ADD LIQUIDITY ****
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool addingTokenA,
        uint staked,
        uint afterIndex,
        uint amountIn,
        uint expire,
        bool enable,
        uint deadline
    ) external returns (uint256 index);
    function addLiquidityETH(
        address tokenA,
        bool addingTokenA,
        uint staked,
        uint afterIndex,
        uint amountAIn,
        uint expire,
        bool enable,
        uint deadline
    ) external payable returns (uint index);

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool removingTokenA,
        address to,
        uint unstake,
        uint afterIndex,
        uint amountOut,
        uint256 reserveOut, 
        uint expire,
        bool enable,
        uint deadline
    ) external;
    function removeLiquidityETH(
        address tokenA,
        bool removingTokenA,
        address to,
        uint unstake,
        uint afterIndex,
        uint amountOut,
        uint256 reserveOut, 
        uint expire,
        bool enable,
        uint deadline
    ) external;
    function removeAllLiquidity(
        address tokenA,
        address tokenB,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeAllLiquidityETH(
        address tokenA,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
}
