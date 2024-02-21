// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../amm/interfaces/IOSWAP_Pair.sol';
import '../oracle/interfaces/IOSWAP_OraclePair.sol';
import '../libraries/TransferHelper.sol';

import './interfaces/IOSWAP_HybridRouter.sol';
import '../libraries/SafeMath.sol';
import '../libraries/Address.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IWETH.sol';
import '../oracle/interfaces/IOSWAP_OracleFactory.sol';

contract OSWAP_HybridRouter is IOSWAP_HybridRouter {
    using SafeMath for uint;

    address public immutable override oracleFactory;
    address public immutable override WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'EXPIRED');
        _;
    }

    constructor(address _oracleFactory, address _WETH) public {
        oracleFactory = _oracleFactory;
        WETH = _WETH;
    }
    
    receive() external payable {
        require(msg.sender == WETH, 'Transfer failed'); // only accept ETH via fallback from the WETH contract
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to, address[] calldata pair, bytes calldata data) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? pair[i + 1] : _to;
            IOSWAP_Pair(pair[i]).swap(
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
        address[] calldata pair,
        uint24[] calldata fee,
        bytes calldata data
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = getAmountsOut(amountIn, path, pair, fee, data);
        require(amounts[amounts.length - 1] >= amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pair[0], amounts[0]
        );
        _swap(amounts, path, to, pair, data);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline,
        address[] calldata pair,
        uint24[] calldata fee,
        bytes calldata data
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = getAmountsIn(amountOut, path, pair, fee, data);
        require(amounts[0] <= amountInMax, 'EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pair[0], amounts[0]
        );
        _swap(amounts, path, to, pair, data);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline, address[] calldata pair, uint24[] calldata fee, bytes calldata data)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'INVALID_PATH');
        amounts = getAmountsOut(msg.value, path, pair, fee, data);
        require(amounts[amounts.length - 1] >= amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        require(IWETH(WETH).transfer(pair[0], amounts[0]), 'Transfer failed');
        _swap(amounts, path, to, pair, data);
    }
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline, address[] calldata pair, uint24[] calldata fee, bytes calldata data)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'INVALID_PATH');
        amounts = getAmountsIn(amountOut, path, pair, fee, data);
        require(amounts[0] <= amountInMax, 'EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pair[0], amounts[0]
        );
        _swap(amounts, path, address(this), pair, data);
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline, address[] calldata pair, uint24[] calldata fee, bytes calldata data)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'INVALID_PATH');
        amounts = getAmountsOut(amountIn, path, pair, fee, data);
        require(amounts[amounts.length - 1] >= amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pair[0], amounts[0]
        );
        _swap(amounts, path, address(this), pair, data);
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline, address[] calldata pair, uint24[] calldata fee, bytes calldata data)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'INVALID_PATH');
        amounts = getAmountsIn(amountOut, path, pair, fee, data);
        require(amounts[0] <= msg.value, 'EXCESSIVE_INPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        require(IWETH(WETH).transfer(pair[0], amounts[0]), 'Transfer failed');
        _swap(amounts, path, to, pair, data);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to, address[] calldata pair, uint24[] calldata fee, bytes memory /*data*/) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            // (address input, address output) = (path[i], path[i + 1]);
            /* (address token0,) = */ sortTokens(path[i], path[i + 1]);
            bool direction = path[i] < path[i + 1];
            IOSWAP_Pair _pair = IOSWAP_Pair(pair[i]);
            uint amountInput = IERC20(path[i]).balanceOf(pair[i]);
            uint amountOutput;
            if (!isOraclePair(pair[i], path[i], path[i + 1])) {
                (uint reserve0, uint reserve1,) = _pair.getReserves();
                (uint reserveInput, uint reserveOutput) = direction ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = amountInput.sub(reserveInput);
                amountOutput = getAmountOut(amountInput, reserveInput, reserveOutput, fee[i]);
            } else {
                (uint balance0, uint balance1) = IOSWAP_OraclePair(pair[i]).getLastBalances();
                amountInput = amountInput.sub(direction ? balance0 : balance1);
                amountOutput = IOSWAP_OraclePair(pair[i]).getAmountOut(path[i], amountInput, new bytes(0));
            }
            (uint amount0Out, uint amount1Out) = direction ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? pair[i + 1] : _to;
            _pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        address[] calldata pair,
        uint24[] calldata fee//,
        // bytes calldata data
    ) external virtual override ensure(deadline) {
        require(path.length >= 2, 'INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pair[0], amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to, pair, fee, new bytes(0));
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
        address[] calldata pair,
        uint24[] calldata fee//,
        // bytes calldata data
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
        require(IWETH(WETH).transfer(pair[0], amountIn), 'Transfer failed');
        }
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to, pair, fee, new bytes(0));
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
        address[] calldata pair,
        uint24[] calldata fee//,
        // bytes calldata data
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == WETH, 'INVALID_PATH');
        require(path.length >= 2, 'INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pair[0], amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this), pair, fee, new bytes(0));
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
    function pairFor(address tokenA, address tokenB) public view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                oracleFactory,
                keccak256(abi.encodePacked(token0, token1)),
                /*oracle*/hex'f16ce672144451d138eed853d57e4616c66cace4e953a121899bbd6e5643ca03'
            ))));
    }
    function isOraclePair(address target, address tokenA, address tokenB) internal view returns (bool) {
        return target == pairFor(tokenA, tokenB);
    }
    // fetches and sorts the reserves for a pair
    function getReserves(address pair, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IOSWAP_Pair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint24 fee) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'INSUFFICIENT_LIQUIDITY');
        require(fee <= 10 ** 6, 'INVALID FEE');
        uint amountInWithFee = amountIn.mul(fee);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(10 ** 6).add(amountInWithFee);
        amountOut = numerator / denominator;
    }
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, uint24 fee) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'INSUFFICIENT_LIQUIDITY');
        require(fee <= 10 ** 6, 'INVALID FEE');
        uint numerator = reserveIn.mul(amountOut).mul(10 ** 6);
        uint denominator = reserveOut.sub(amountOut).mul(fee);
        amountIn = (numerator / denominator).add(1);
    }


    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(uint amountIn, address[] memory path, address[] calldata pair, uint24[] calldata fee, bytes calldata data)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        require(path.length >= 2, 'INVALID_PATH');
        require(path.length - 1 == pair.length, 'INVALID_PAIRS');
        require(pair.length == fee.length, 'INVALID_FEE');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            if (!isOraclePair(pair[i], path[i], path[i + 1])) {
                (uint reserveIn, uint reserveOut) = getReserves(pair[i], path[i], path[i + 1]);
                amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, fee[i]);
            } else {
                amounts[i + 1] = IOSWAP_OraclePair(pair[i]).getAmountOut(path[i], amounts[i], data);
            }
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(uint amountOut, address[] memory path, address[] calldata pair, uint24[] calldata fee, bytes calldata data)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        require(path.length >= 2, 'INVALID_PATH');
        require(path.length - 1 == pair.length, 'INVALID_PAIRS');
        require(pair.length == fee.length, 'INVALID_FEE');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            if (!isOraclePair(pair[i - 1], path[i - 1], path[i])) {
                (uint reserveIn, uint reserveOut) = getReserves(pair[i - 1], path[i - 1], path[i]);
                amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, fee[i - 1]);
            } else {
                amounts[i - 1] = IOSWAP_OraclePair(pair[i - 1]).getAmountIn(path[i], amounts[i], data);
            }
        }
    }
}
