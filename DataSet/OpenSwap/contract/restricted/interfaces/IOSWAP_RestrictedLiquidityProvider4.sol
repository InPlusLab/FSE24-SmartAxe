// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

interface IOSWAP_RestrictedLiquidityProvider4 {
    function factory() external view returns (address);
    function WETH() external view returns (address);
    function govToken() external view returns (address);
    function configStore() external view returns (address);

    // **** ADD LIQUIDITY ****
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool addingTokenA,
        uint256[9] calldata params,
        bytes32 merkleRoot,
        string calldata allowlistIpfsCid
    ) external returns (address pair, uint256 _offerIndex);
    function addLiquidityETH(
        address tokenA,
        bool addingTokenA,
        uint256[9] calldata params,
        bytes32 merkleRoot,
        string calldata allowlistIpfsCid
    ) external payable returns (address pair, uint256 _offerIndex);


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
        uint256 feeOut,
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
        uint256 feeOut,
        uint256 deadline
    ) external;
    function removeAllLiquidity(
        address tokenA,
        address tokenB,
        address to,
        uint256 pairIndex,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 feeOut);
    function removeAllLiquidityETH(
        address tokenA,
        address to,
        uint256 pairIndex,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH, uint256 feeOut);
}
