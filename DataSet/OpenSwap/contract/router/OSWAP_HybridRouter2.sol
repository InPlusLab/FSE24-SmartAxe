// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../libraries/TransferHelper.sol';

import './interfaces/IOSWAP_HybridRouter2.sol';
import '../libraries/SafeMath.sol';
import '../libraries/Address.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IWETH.sol';
import './interfaces/IOSWAP_HybridRouterRegistry.sol';
import '../oracle/interfaces/IOSWAP_OracleFactory.sol';

interface IOSWAP_PairV1 {
    function getReserves() external view returns (uint112, uint112, uint32);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IOSWAP_PairV2 {
    function getLastBalances() external view returns (uint256, uint256);
    function getAmountOut(address tokenIn, uint256 amountIn, bytes calldata data) external view returns (uint256 amountOut);
    function getAmountIn(address tokenOut, uint256 amountOut, bytes calldata data) external view returns (uint256 amountIn);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IOSWAP_PairV3 {
    function getLastBalances() external view returns (uint256, uint256);
    function getAmountOut(address tokenIn, uint256 amountIn, address trader, bytes calldata data) external view returns (uint256 amountOut);
    function getAmountIn(address tokenOut, uint256 amountOut, address trader, bytes calldata data) external view returns (uint256 amountIn);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, address trader, bytes calldata data) external;
}

interface IOSWAP_PairV4 {
    function getReserves() external view returns (uint112, uint112, uint32);
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;
}

contract OSWAP_HybridRouter2 is IOSWAP_HybridRouter2 {
    using SafeMath for uint;

    address public immutable override registry;
    address public immutable override WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'EXPIRED');
        _;
    }

    constructor(address _registry, address _WETH) public {
        registry = _registry;
        WETH = _WETH;
    }
    
    receive() external payable {
        require(msg.sender == WETH, 'TRANSFER_FAILED'); // only accept ETH via fallback from the WETH contract
    }

    function getPathIn(address[] memory pair, address tokenIn) public override view returns (address[] memory path) {
        uint256 length = pair.length;
        require(length > 0, 'INVALID_PATH');
        path = new address[](length + 1);
        path[0] = tokenIn;
        (address[] memory token0, address[] memory token1) = IOSWAP_HybridRouterRegistry(registry).getPairTokens(pair);
        for (uint256 i = 0 ; i < length ; i++) {
            path[i + 1] = _findToken(token0[i], token1[i], tokenIn);
            tokenIn = path[i + 1];
        }
    }
    function getPathOut(address[] memory pair, address tokenOut) public override view returns (address[] memory path) {
        uint256 length = pair.length;
        require(length > 0, 'INVALID_PATH');
        path = new address[](length + 1);
        path[path.length - 1] = tokenOut;
        (address[] memory token0, address[] memory token1) = IOSWAP_HybridRouterRegistry(registry).getPairTokens(pair);
        for (uint256 i = length - 1 ; i < length ; i--) {
            path[i] = _findToken(token0[i], token1[i], tokenOut);
            tokenOut = path[i];
        }
    }
    function _findToken(address token0, address token1, address token) internal pure returns (address){
        require(token0 != address(0) && token1 != address(0), 'PAIR_NOT_DEFINED');
        if (token0 == token)
            return token1;
        else if (token1 == token)
            return token0;
        else
            revert('PAIR_NOT_MATCH');
    }
    
    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to, address[] memory pair, bytes[] memory dataChunks, uint256 amountOutMin) internal virtual {
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(_to);
        for (uint i; i < path.length - 1; i++) {
            bool direction;
            {
                (address input, address output) = (path[i], path[i + 1]);
                (address token0,) = sortTokens(input, output);
                direction = input == token0;
            }
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = direction ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? pair[i + 1] : _to;
            uint256 typeCode = protocolTypeCode(pair[i]);
            if (typeCode == 1) {
                IOSWAP_PairV1(pair[i]).swap(
                    amount0Out, amount1Out, to, new bytes(0)
                );
            } else if (typeCode == 2) {
                IOSWAP_PairV2(pair[i]).swap(
                    amount0Out, amount1Out, to, dataChunks[i]
                );
            } else if (typeCode == 3) {
                IOSWAP_PairV3(pair[i]).swap(
                    amount0Out, amount1Out, to, msg.sender, dataChunks[i]
                );
            } else if (typeCode == 4) {
                IOSWAP_PairV4(pair[i]).swap(
                    amount0Out, amount1Out, to
                );                
            }
        }
        require(
            IERC20(path[path.length - 1]).balanceOf(_to).sub(balanceBefore) >= amountOutMin,
            'HybridRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] memory pair,
        address tokenIn,
        address to,
        uint deadline,
        bytes memory data
    ) external virtual override ensure(deadline) returns (address[] memory path, uint[] memory amounts) {
        path = getPathIn(pair, tokenIn);
        bytes[] memory dataChunks;
        (amounts, dataChunks) = getAmountsOut(amountIn, path, pair, data);
        require(amounts[amounts.length - 1] >= amountOutMin, 'HybridRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pair[0], amounts[0]
        );
        _swap(amounts, path, to, pair, dataChunks, amountOutMin);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] memory pair,
        address tokenOut,
        address to,
        uint deadline,
        bytes memory data
    ) external virtual override ensure(deadline) returns (address[] memory path, uint[] memory amounts) {
        path = getPathOut(pair, tokenOut);
        bytes[] memory dataChunks;
        (amounts, dataChunks) = getAmountsIn(amountOut, path, pair, data);
        uint256 _amountOut = amountOut;
        require(amounts[0] <= amountInMax, 'HybridRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pair[0], amounts[0]
        );
        _swap(amounts, path, to, pair, dataChunks, _amountOut);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] memory pair, address to, uint deadline, bytes memory data)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (address[] memory path, uint[] memory amounts)
    {
        path = getPathIn(pair, WETH);
        bytes[] memory dataChunks;
        (amounts, dataChunks) = getAmountsOut(msg.value, path, pair, data);
        require(amounts[amounts.length - 1] >= amountOutMin, 'HybridRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        require(IWETH(WETH).transfer(pair[0], amounts[0]), 'TRANSFER_FAILED');
        _swap(amounts, path, to, pair, dataChunks, amountOutMin);
    }
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] memory pair, address to, uint deadline, bytes memory data)
        external
        virtual
        override
        ensure(deadline)
        returns (address[] memory path, uint[] memory amounts)
    {
        path = getPathOut(pair, WETH);
        bytes[] memory dataChunks;
        (amounts, dataChunks) = getAmountsIn(amountOut, path, pair, data);
        require(amounts[0] <= amountInMax, 'HybridRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pair[0], amounts[0]
        );
        _swap(amounts, path, address(this), pair, dataChunks, amountOut);
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] memory pair, address to, uint deadline, bytes memory data)
        external
        virtual
        override
        ensure(deadline)
        returns (address[] memory path, uint[] memory amounts)
    {
        path = getPathOut(pair, WETH);
        bytes[] memory dataChunks;
        (amounts, dataChunks) = getAmountsOut(amountIn, path, pair, data);
        require(amounts[amounts.length - 1] >= amountOutMin, 'HybridRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pair[0], amounts[0]
        );
        _swap(amounts, path, address(this), pair, dataChunks, amountOutMin);
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapETHForExactTokens(uint amountOut, address[] memory pair, address to, uint deadline, bytes memory data)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (address[] memory path, uint[] memory amounts)
    {
        path = getPathIn(pair, WETH);
        bytes[] memory dataChunks;
        (amounts, dataChunks) = getAmountsIn(amountOut, path, pair, data);
        require(amounts[0] <= msg.value, 'HybridRouter: EXCESSIVE_INPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        require(IWETH(WETH).transfer(pair[0], amounts[0]), 'TRANSFER_FAILED');
        _swap(amounts, path, to, pair, dataChunks, amountOut);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to, address[] memory pair, bytes memory data) internal virtual {
        uint256 offset;
        for (uint i; i < path.length - 1; i++) {
            // (address input, address output) = (path[i], path[i + 1]);
            /* (address token0,) = */ sortTokens(path[i], path[i + 1]);
            bool direction = path[i] < path[i + 1];
            uint amountInput = IERC20(path[i]).balanceOf(pair[i]);
            uint amountOutput;

            uint256 typeCode = protocolTypeCode(pair[i]);
            address to = i < path.length - 2 ? pair[i + 1] : _to;
            if (typeCode == 1 || typeCode == 4) {
                { // scope to avoid stack too deep errors
                IOSWAP_PairV1 _pair = IOSWAP_PairV1(pair[i]);
                (uint reserve0, uint reserve1,) = _pair.getReserves();
                (uint reserveInput, uint reserveOutput) = direction ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = amountInput.sub(reserveInput);
                (uint256 fee,uint256 feeBase) = IOSWAP_HybridRouterRegistry(registry).getFee(address(_pair));
                amountOutput = getAmountOut(amountInput, reserveInput, reserveOutput, fee, feeBase);
                }
                (uint amount0Out, uint amount1Out) = direction ? (uint(0), amountOutput) : (amountOutput, uint(0));
                
                if (typeCode == 4) {
                    IOSWAP_PairV4(pair[i]).swap(amount0Out, amount1Out, to);
                }
                else {
                    IOSWAP_PairV1(pair[i]).swap(amount0Out, amount1Out, to, new bytes(0));
                }
            }           
            else {
                bytes memory next;
                (offset, next) = cut(data, offset);
                {
                (uint balance0, uint balance1) = IOSWAP_PairV2(pair[i]).getLastBalances();
                amountInput = amountInput.sub(direction ? balance0 : balance1);
                }
                if (typeCode == 2) {
                    IOSWAP_PairV2 _pair = IOSWAP_PairV2(pair[i]);
                    amountOutput = _pair.getAmountOut(path[i], amountInput, next);
                    (uint amount0Out, uint amount1Out) = direction ? (uint(0), amountOutput) : (amountOutput, uint(0));
                    _pair.swap(amount0Out, amount1Out, to, next);
                } else /*if (typeCode == 3)*/ {
                    IOSWAP_PairV3 _pair = IOSWAP_PairV3(pair[i]);
                    amountOutput = _pair.getAmountOut(path[i], amountInput, msg.sender, next);
                    (uint amount0Out, uint amount1Out) = direction ? (uint(0), amountOutput) : (amountOutput, uint(0));
                    _pair.swap(amount0Out, amount1Out, to, msg.sender, next);
                }
            }
        }
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata pair,
        address tokenIn,
        address to,
        uint deadline,
        bytes calldata data
    ) external virtual override ensure(deadline) {
        address[] memory path = getPathIn(pair, tokenIn);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pair[0], amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to, pair, data);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'HybridRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata pair,
        address to,
        uint deadline,
        bytes calldata data
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        address[] memory path = getPathIn(pair, WETH);
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        require(IWETH(WETH).transfer(pair[0], amountIn), 'TRANSFER_FAILED');
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to, pair, data);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'HybridRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata pair,
        address to,
        uint deadline,
        bytes calldata data
    )
        external
        virtual
        override
        ensure(deadline)
    {
        address[] memory path = getPathOut(pair, WETH);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, pair[0], amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this), pair, data);
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'HybridRouter: INSUFFICIENT_OUTPUT_AMOUNT');
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
    function protocolTypeCode(address pair) internal view returns (uint256 typeCode) {
        typeCode =  IOSWAP_HybridRouterRegistry(registry).getTypeCode(pair);
        require(typeCode > 0 && typeCode < 5, 'PAIR_NOT_REGCONIZED');
    }
    // fetches and sorts the reserves for a pair
    function getReserves(address pair, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IOSWAP_PairV1(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint256 fee, uint256 feeBase) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(fee);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(feeBase).add(amountInWithFee);
        amountOut = numerator / denominator;
    }
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, uint256 fee, uint256 feeBase) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'HybridRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(feeBase);
        uint denominator = reserveOut.sub(amountOut).mul(fee);
        amountIn = (numerator / denominator).add(1);
    }

    // every data/payload block prefixed with uint256 size, followed by the data/payload
    function cut(bytes memory data, uint256 offset) internal pure returns (uint256 nextOffset, bytes memory out) {
        assembly {
            let total := mload(data)
            offset := add(offset, 0x20)
            if or(lt(offset, total), eq(offset, total)) {
                let size := mload(add(data, offset))
                if gt(add(offset, size), total) {
                    revert(0, 0)
                }
                let mark := mload(0x40)
                mstore(0x40, add(mark, add(size, 0x20)))
                mstore(mark, size)
                nextOffset := add(offset, size)
                out := mark

                mark := add(mark, 0x20)
                let src := add(add(data, offset), 0x20)
                for { let i := 0 } lt(i, size) { i := add(i, 0x20) } {
                    mstore(add(mark, i), mload(add(src, i)))
                }

                let i := sub(size, 0x20)
                mstore(add(mark, i), mload(add(src, i)))
            }
        }
    }

    function getAmountsOut(uint amountIn, address[] memory path, address[] memory pair, bytes memory data)
        internal
        view
        virtual
        returns (uint[] memory amounts, bytes[] memory dataChunks)
    {
        amounts = new uint[](path.length);
        dataChunks = new bytes[](pair.length);
        amounts[0] = amountIn;
        uint256 offset;
        for (uint i; i < path.length - 1; i++) {
            uint256 typeCode = protocolTypeCode(pair[i]);
            if (typeCode == 1 || typeCode == 4) {
                (uint reserveIn, uint reserveOut) = getReserves(pair[i], path[i], path[i + 1]);
                (uint256 fee,uint256 feeBase) = IOSWAP_HybridRouterRegistry(registry).getFee(pair[i]);
                amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, fee, feeBase);
            } else {
                bytes memory next;
                (offset, next) = cut(data, offset);
                if (typeCode == 2) {
                    amounts[i + 1] = IOSWAP_PairV2(pair[i]).getAmountOut(path[i], amounts[i], next);
                } else /*if (typeCode == 3)*/ {
                    amounts[i + 1] = IOSWAP_PairV3(pair[i]).getAmountOut(path[i], amounts[i], msg.sender, next);
                }
                dataChunks[i] = next;
            }
        }
    }
    function getAmountsIn(uint amountOut, address[] memory path, address[] memory pair, bytes memory data)
        internal
        view
        virtual
        returns (uint[] memory amounts, bytes[] memory dataChunks)
    {
        amounts = new uint[](path.length);
        dataChunks = new bytes[](pair.length);
        amounts[amounts.length - 1] = amountOut;
        uint256 offset;
        for (uint i = path.length - 1; i > 0; i--) {
            uint256 typeCode = protocolTypeCode(pair[i - 1]);
            if (typeCode == 1 || typeCode == 4) {
                (uint reserveIn, uint reserveOut) = getReserves(pair[i - 1], path[i - 1], path[i]);
                (uint256 fee,uint256 feeBase) = IOSWAP_HybridRouterRegistry(registry).getFee(pair[i - 1]);
                amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, fee, feeBase);
            } else {
                bytes memory next;
                (offset, next) = cut(data, offset);
                if (typeCode == 2) {
                    amounts[i - 1] = IOSWAP_PairV2(pair[i - 1]).getAmountIn(path[i], amounts[i], next);
                } else if (typeCode == 3) {
                    amounts[i - 1] = IOSWAP_PairV3(pair[i - 1]).getAmountIn(path[i], amounts[i], msg.sender, next);
                }
                dataChunks[i - 1] = next;
            }
        }
    }

    function getAmountsInStartsWith(uint amountOut, address[] calldata pair, address tokenIn, bytes calldata data) external view override returns (uint[] memory amounts) {
        address[] memory path = getPathIn(pair, tokenIn);
        (amounts,) = getAmountsIn(amountOut, path, pair, data);
    }
    function getAmountsInEndsWith(uint amountOut, address[] calldata pair, address tokenOut, bytes calldata data) external view override returns (uint[] memory amounts) {
        address[] memory path = getPathOut(pair, tokenOut);
        (amounts,) = getAmountsIn(amountOut, path, pair, data);
    }
    function getAmountsOutStartsWith(uint amountIn, address[] calldata pair, address tokenIn, bytes calldata data) external view override returns (uint[] memory amounts) {
        address[] memory path = getPathIn(pair, tokenIn);
        (amounts,) = getAmountsOut(amountIn, path, pair, data);
    }
    function getAmountsOutEndsWith(uint amountIn, address[] calldata pair, address tokenOut, bytes calldata data) external view override returns (uint[] memory amounts) {
        address[] memory path = getPathOut(pair, tokenOut);
        (amounts,) = getAmountsOut(amountIn, path, pair, data);
    }
}
