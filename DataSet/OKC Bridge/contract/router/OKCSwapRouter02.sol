// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import '../libraries/TransferHelper.sol';

import '../interfaces/IOKCSwapFactory.sol';
import '../interfaces/IOKCSwapRouter02.sol';
import '../libraries/OKCSwapLibrary.sol';
import '../libraries/SafeMath.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IWOKT.sol';

contract OKCSwapRouter02 is IOKCSwapRouter02 {
    using SafeMath for uint;

    address public immutable override factory;
    address public immutable override WOKT;
    bytes32 public immutable override pairCodeHash;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'OKCSwapRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _WOKT, bytes32 _pairCodeHash) public {
        factory = _factory;
        WOKT = _WOKT;
        pairCodeHash = _pairCodeHash;
    }

    receive() external payable {
        assert(msg.sender == WOKT); // only accept OKT via fallback from the WOKT contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (IOKCSwapFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IOKCSwapFactory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = OKCSwapLibrary.getReserves(factory, tokenA, tokenB, pairCodeHash);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = OKCSwapLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'OKCSwapRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = OKCSwapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'OKCSwapRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = OKCSwapLibrary.pairFor(factory, tokenA, tokenB, pairCodeHash);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IOKCSwapPair(pair).mint(to);
    }
    function addLiquidityOKT(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountOKTMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountOKT, uint liquidity) {
        (amountToken, amountOKT) = _addLiquidity(
            token,
            WOKT,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountOKTMin
        );
        address pair = OKCSwapLibrary.pairFor(factory, token, WOKT, pairCodeHash);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWOKT(WOKT).deposit{value: amountOKT}();
        assert(IWOKT(WOKT).transfer(pair, amountOKT));
        liquidity = IOKCSwapPair(pair).mint(to);
        // refund dust OKT, if any
        if (msg.value > amountOKT) TransferHelper.safeTransferOKT(msg.sender, msg.value - amountOKT);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = OKCSwapLibrary.pairFor(factory, tokenA, tokenB, pairCodeHash);
        IOKCSwapPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IOKCSwapPair(pair).burn(to);
        (address token0,) = OKCSwapLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'OKCSwapRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'OKCSwapRouter: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityOKT(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountOKTMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountOKT) {
        (amountToken, amountOKT) = removeLiquidity(
            token,
            WOKT,
            liquidity,
            amountTokenMin,
            amountOKTMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWOKT(WOKT).withdraw(amountOKT);
        TransferHelper.safeTransferOKT(to, amountOKT);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = OKCSwapLibrary.pairFor(factory, tokenA, tokenB, pairCodeHash);
        uint value = approveMax ? uint(-1) : liquidity;
        IOKCSwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    function removeLiquidityOKTWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountOKTMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountToken, uint amountOKT) {
        address pair = OKCSwapLibrary.pairFor(factory, token, WOKT, pairCodeHash);
        uint value = approveMax ? uint(-1) : liquidity;
        IOKCSwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountOKT) = removeLiquidityOKT(token, liquidity, amountTokenMin, amountOKTMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityOKTSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountOKTMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountOKT) {
        (, amountOKT) = removeLiquidity(
            token,
            WOKT,
            liquidity,
            amountTokenMin,
            amountOKTMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWOKT(WOKT).withdraw(amountOKT);
        TransferHelper.safeTransferOKT(to, amountOKT);
    }
    function removeLiquidityOKTWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountOKTMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountOKT) {
        address pair = OKCSwapLibrary.pairFor(factory, token, WOKT, pairCodeHash);
        uint value = approveMax ? uint(-1) : liquidity;
        IOKCSwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountOKT = removeLiquidityOKTSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountOKTMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = OKCSwapLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? OKCSwapLibrary.pairFor(factory, output, path[i + 2], pairCodeHash) : _to;
            IOKCSwapPair(OKCSwapLibrary.pairFor(factory, input, output, pairCodeHash)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = OKCSwapLibrary.getAmountsOut(factory, amountIn, path, pairCodeHash);
        require(amounts[amounts.length - 1] >= amountOutMin, 'OKCSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OKCSwapLibrary.pairFor(factory, path[0], path[1], pairCodeHash), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = OKCSwapLibrary.getAmountsIn(factory, amountOut, path, pairCodeHash);
        require(amounts[0] <= amountInMax, 'OKCSwapRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OKCSwapLibrary.pairFor(factory, path[0], path[1], pairCodeHash), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapExactOKTForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WOKT, 'OKCSwapRouter: INVALID_PATH');
        amounts = OKCSwapLibrary.getAmountsOut(factory, msg.value, path, pairCodeHash);
        require(amounts[amounts.length - 1] >= amountOutMin, 'OKCSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWOKT(WOKT).deposit{value: amounts[0]}();
        assert(IWOKT(WOKT).transfer(OKCSwapLibrary.pairFor(factory, path[0], path[1], pairCodeHash), amounts[0]));
        _swap(amounts, path, to);
    }
    function swapTokensForExactOKT(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WOKT, 'OKCSwapRouter: INVALID_PATH');
        amounts = OKCSwapLibrary.getAmountsIn(factory, amountOut, path, pairCodeHash);
        require(amounts[0] <= amountInMax, 'OKCSwapRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OKCSwapLibrary.pairFor(factory, path[0], path[1], pairCodeHash), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWOKT(WOKT).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferOKT(to, amounts[amounts.length - 1]);
    }
    function swapExactTokensForOKT(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WOKT, 'OKCSwapRouter: INVALID_PATH');
        amounts = OKCSwapLibrary.getAmountsOut(factory, amountIn, path, pairCodeHash);
        require(amounts[amounts.length - 1] >= amountOutMin, 'OKCSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OKCSwapLibrary.pairFor(factory, path[0], path[1], pairCodeHash), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWOKT(WOKT).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferOKT(to, amounts[amounts.length - 1]);
    }
    function swapOKTForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WOKT, 'OKCSwapRouter: INVALID_PATH');
        amounts = OKCSwapLibrary.getAmountsIn(factory, amountOut, path, pairCodeHash);
        require(amounts[0] <= msg.value, 'OKCSwapRouter: EXCESSIVE_INPUT_AMOUNT');
        IWOKT(WOKT).deposit{value: amounts[0]}();
        assert(IWOKT(WOKT).transfer(OKCSwapLibrary.pairFor(factory, path[0], path[1], pairCodeHash), amounts[0]));
        _swap(amounts, path, to);
        // refund dust OKT, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferOKT(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = OKCSwapLibrary.sortTokens(input, output);
            IOKCSwapPair pair = IOKCSwapPair(OKCSwapLibrary.pairFor(factory, input, output, pairCodeHash));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = OKCSwapLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? OKCSwapLibrary.pairFor(factory, output, path[i + 2], pairCodeHash) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OKCSwapLibrary.pairFor(factory, path[0], path[1], pairCodeHash), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'OKCSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactOKTForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        require(path[0] == WOKT, 'OKCSwapRouter: INVALID_PATH');
        uint amountIn = msg.value;
        IWOKT(WOKT).deposit{value: amountIn}();
        assert(IWOKT(WOKT).transfer(OKCSwapLibrary.pairFor(factory, path[0], path[1], pairCodeHash), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'OKCSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForOKTSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == WOKT, 'OKCSwapRouter: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OKCSwapLibrary.pairFor(factory, path[0], path[1], pairCodeHash), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WOKT).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'OKCSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWOKT(WOKT).withdraw(amountOut);
        TransferHelper.safeTransferOKT(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return OKCSwapLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return OKCSwapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return OKCSwapLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return OKCSwapLibrary.getAmountsOut(factory, amountIn, path, pairCodeHash);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return OKCSwapLibrary.getAmountsIn(factory, amountOut, path, pairCodeHash);
    }
}
