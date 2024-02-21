// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

interface IOSWAP_OracleRouter {

    function ammFactory() external view returns (address);
    function oracleFactory() external view returns (address);
    function WETH() external view returns (address);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata useOracle,
        bytes calldata data
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata useOracle,
        bytes calldata data
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline, bool[] calldata useOracle, bytes calldata data)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline, bool[] calldata useOracle, bytes calldata data)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline, bool[] calldata useOracle, bytes calldata data)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline, bool[] calldata useOracle, bytes calldata data)
        external
        payable
        returns (uint[] memory amounts);

    function getLatestPrice(address tokenIn, address tokenOut, bytes calldata data) external view returns (uint256);
    function getAmountOut(uint amountIn, address tokenIn, address tokenOut, bytes calldata data) external view returns (uint amountOut);
    function getAmountIn(uint amountOut, address tokenIn, address tokenOut, bytes calldata data) external view returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path, bool[] calldata useOracle, bytes calldata data) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path, bool[] calldata useOracle, bytes calldata data) external view returns (uint[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata useOracle,
        bytes calldata data
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata useOracle,
        bytes calldata data
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata useOracle,
        bytes calldata data
    ) external;
}
