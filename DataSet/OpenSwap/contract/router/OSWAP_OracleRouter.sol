// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../amm/interfaces/IOSWAP_Pair.sol';
import '../oracle/interfaces/IOSWAP_OraclePair.sol';
import '../oracle/interfaces/IOSWAP_OracleFactory.sol';
import '../gov/interfaces/IOAXDEX_Governance.sol';
import '../libraries/TransferHelper.sol';

import './interfaces/IOSWAP_OracleRouter.sol';
import '../libraries/SafeMath.sol';
import '../libraries/Address.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IWETH.sol';

contract OSWAP_OracleRouter is IOSWAP_OracleRouter {
    using SafeMath for uint;

    address public immutable override ammFactory;
    address public immutable override oracleFactory;
    address public immutable override WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'EXPIRED');
        _;
    }

    modifier onlyEndUser() {
        require((tx.origin == msg.sender && !Address.isContract(msg.sender)) || IOSWAP_OracleFactory(oracleFactory).isWhitelisted(msg.sender));
        _;
    }

    constructor(address _ammFactory, address _oracleFactory, address _WETH) public {
        ammFactory = _ammFactory;
        oracleFactory = _oracleFactory;
        WETH = _WETH;
    }
    
    receive() external payable {
        require(msg.sender == WETH, 'Transfer failed'); // only accept ETH via fallback from the WETH contract
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] calldata path, address _to, bool[] calldata useOracle, bytes calldata data) internal virtual onlyEndUser {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            uint amount0Out = amounts[i + 1];
            uint amount1Out;
            {
            (address token0,) = sortTokens(input, output);
            (amount0Out, amount1Out) = input == token0 ? (uint(0), amount0Out) : (amount0Out, uint(0));
            }
            address to = i < path.length - 2 ? pairFor(output, path[i + 2], useOracle[i + 1]) : _to;
            IOSWAP_OraclePair(pairFor(input, output, useOracle[i])).swap(
                amount0Out, amount1Out, to, data
            );
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata useOracle,
        bytes calldata data
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = getAmountsOut(amountIn, path, useOracle, data);
        require(amounts[amounts.length - 1] >= amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pairFor(path[0], path[1], useOracle[0]), amounts[0]
        );
        _swap(amounts, path, to, useOracle, data);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata useOracle,
        bytes calldata data
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = getAmountsIn(amountOut, path, useOracle, data);
        require(amounts[0] <= amountInMax, 'EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pairFor(path[0], path[1], useOracle[0]), amounts[0]
        );
        _swap(amounts, path, to, useOracle, data);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline, bool[] calldata useOracle, bytes calldata data)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'INVALID_PATH');
        amounts = getAmountsOut(msg.value, path, useOracle, data);
        require(amounts[amounts.length - 1] >= amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        require(IWETH(WETH).transfer(pairFor(path[0], path[1], useOracle[0]), amounts[0]), 'Transfer failed');
        _swap(amounts, path, to, useOracle, data);
    }
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline, bool[] calldata useOracle, bytes calldata data)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'INVALID_PATH');
        amounts = getAmountsIn(amountOut, path, useOracle, data);
        require(amounts[0] <= amountInMax, 'EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pairFor(path[0], path[1], useOracle[0]), amounts[0]
        );
        _swap(amounts, path, address(this), useOracle, data);
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline, bool[] calldata useOracle, bytes calldata data)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'INVALID_PATH');
        amounts = getAmountsOut(amountIn, path, useOracle, data);
        require(amounts[amounts.length - 1] >= amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pairFor(path[0], path[1], useOracle[0]), amounts[0]
        );
        _swap(amounts, path, address(this), useOracle, data);
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline, bool[] calldata useOracle, bytes calldata data)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'INVALID_PATH');
        amounts = getAmountsIn(amountOut, path, useOracle, data);
        require(amounts[0] <= msg.value, 'EXCESSIVE_INPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        require(IWETH(WETH).transfer(pairFor(path[0], path[1], useOracle[0]), amounts[0]), 'Transfer failed');
        _swap(amounts, path, to, useOracle, data);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] calldata path, address _to, bool[] calldata useOracle, bytes memory data) internal virtual onlyEndUser {
        require(path.length - 1 == useOracle.length, 'INVALID_ORACLE');
        for (uint i; i < path.length - 1; i++) {
            address output = path[i + 1];
            IOSWAP_OraclePair pair;
            uint amount0Out;
            uint amount1Out;
            {
            address input = path[i];
            (address token0,) = sortTokens(input, output);
            bool direction = input == token0;
            pair = IOSWAP_OraclePair(pairFor(input, output, useOracle[i]));
            { // scope to avoid stack too deep errors
            uint amountInput;
            (uint reserve0, uint reserve1) = pair.getLastBalances();
            { // scope to avoid stack too deep errors
            (uint reserveInput, /*uint reserveOutput*/) = direction ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            }
            // uint price = getPrice(path[i], path[i + 1]);
            amount0Out = pair.getAmountOut(input, amountInput, data);
            }
            (amount0Out, amount1Out) = direction ? (uint(0), amount0Out) : (amount0Out, uint(0));
            }
            address to = i < path.length - 2 ? pairFor(output, path[i + 2], useOracle[i + 1]) : _to;
            pair.swap(amount0Out, amount1Out, to, data);
        }
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata useOracle,
        bytes calldata data
    ) external virtual override ensure(deadline) {
        require(path.length >= 2, 'INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pairFor(path[0], path[1], useOracle[0]), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to, useOracle, data);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata useOracle,
        bytes calldata data
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        require(path[0] == WETH, 'INVALID_PATH');
        require(path.length >= 2, 'INVALID_PATH');
        {
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        require(IWETH(WETH).transfer(pairFor(path[0], path[1], useOracle[0]), amountIn), 'Transfer failed');
        }
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to, useOracle, data);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bool[] calldata useOracle,
        bytes calldata data
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == WETH, 'INVALID_PATH');
        require(path.length >= 2, 'INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pairFor(path[0], path[1], useOracle[0]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this), useOracle, data);
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB, bool oracle) internal view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                oracle ? oracleFactory : ammFactory,
                keccak256(abi.encodePacked(token0, token1)),
                oracle ? 
                /*oracle*/hex'f16ce672144451d138eed853d57e4616c66cace4e953a121899bbd6e5643ca03' : // oracle init code hash
                /*amm*/hex'5c193265bc1f16117085a454b86f04b786de5c40d54a45dc24869043eb75f155' // amm init code hash
            ))));
    }

    function getLatestPrice(address tokenIn, address tokenOut, bytes calldata data) public override view returns (uint256) {
        bool direction = (tokenIn < tokenOut);
        return IOSWAP_OraclePair(pairFor(tokenIn, tokenOut, true)).getLatestPrice(direction, data);
    }
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, address tokenIn, address tokenOut, bytes calldata data)
        public
        view
        virtual
        override
        returns (uint amountOut)
    {
        return IOSWAP_OraclePair(pairFor(tokenIn, tokenOut, true)).getAmountOut(tokenIn, amountIn, data);
    }
 
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, address tokenIn, address tokenOut, bytes calldata data)
        public
        view
        virtual
        override
        returns (uint amountIn)
    {
        return IOSWAP_OraclePair(pairFor(tokenIn, tokenOut, true)).getAmountIn(tokenOut, amountOut, data);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(uint amountIn, address[] calldata path, bool[] calldata useOracle, bytes calldata data)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        require(path.length >= 2, 'INVALID_PATH');
        require(path.length - 1 == useOracle.length, 'INVALID_ORACLE');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            amounts[i + 1] = useOracle[i] ? getAmountOut(amounts[i], path[i], path[i + 1], data) :
                                            IOSWAP_Pair(pairFor(path[i], path[i + 1], false)).getAmountOut(path[i], amounts[i]);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(uint amountOut, address[] calldata path, bool[] calldata useOracle, bytes calldata data)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        require(path.length >= 2, 'INVALID_PATH');
        require(path.length - 1 == useOracle.length, 'INVALID_ORACLE');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            amounts[i - 1] = useOracle[i - 1] ? getAmountIn(amounts[i], path[i - 1], path[i], data) :
                                            IOSWAP_Pair(pairFor(path[i - 1], path[i], false)).getAmountIn(path[i], amounts[i]);
        }
    }
}
