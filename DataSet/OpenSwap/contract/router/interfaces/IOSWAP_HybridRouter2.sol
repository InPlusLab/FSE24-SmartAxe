// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

interface IOSWAP_HybridRouter2 {

    function registry() external view returns (address);
    function WETH() external view returns (address);

    function getPathIn(address[] calldata pair, address tokenIn) external view returns (address[] memory path);
    function getPathOut(address[] calldata pair, address tokenOut) external view returns (address[] memory path);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata pair,
        address tokenIn,
        address to,
        uint deadline,
        bytes calldata data
    ) external returns (address[] memory path, uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata pair,
        address tokenOut,
        address to,
        uint deadline,
        bytes calldata data
    ) external returns (address[] memory path, uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata pair, address to, uint deadline, bytes calldata data)
        external
        payable
        returns (address[] memory path, uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata pair, address to, uint deadline, bytes calldata data)
        external
        returns (address[] memory path, uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata pair, address to, uint deadline, bytes calldata data)
        external
        returns (address[] memory path, uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata pair, address to, uint deadline, bytes calldata data)
        external
        payable
        returns (address[] memory path, uint[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address tokenIn,
        address to,
        uint deadline,
        bytes calldata data
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bytes calldata data
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bytes calldata data
    ) external;

    function getAmountsInStartsWith(uint amountOut, address[] calldata pair, address tokenIn, bytes calldata data) external view returns (uint[] memory amounts);
    function getAmountsInEndsWith(uint amountOut, address[] calldata pair, address tokenOut, bytes calldata data) external view returns (uint[] memory amounts);
    function getAmountsOutStartsWith(uint amountIn, address[] calldata pair, address tokenIn, bytes calldata data) external view returns (uint[] memory amounts);
    function getAmountsOutEndsWith(uint amountIn, address[] calldata pair, address tokenOut, bytes calldata data) external view returns (uint[] memory amounts);
}
