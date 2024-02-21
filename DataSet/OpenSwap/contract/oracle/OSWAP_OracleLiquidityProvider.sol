// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './interfaces/IOSWAP_OracleLiquidityProvider.sol';
import './interfaces/IOSWAP_OraclePair.sol';
import './interfaces/IOSWAP_OracleFactory.sol';
import '../gov/interfaces/IOAXDEX_Governance.sol';
import '../libraries/TransferHelper.sol';
import '../libraries/SafeMath.sol';
import '../interfaces/IWETH.sol';

contract OSWAP_OracleLiquidityProvider is IOSWAP_OracleLiquidityProvider {
    using SafeMath for uint;

    address public immutable override factory;
    address public immutable override WETH;
    address public immutable override govToken;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
        govToken = IOAXDEX_Governance(IOSWAP_OracleFactory(_factory).governance()).oaxToken();
    }
    
    receive() external payable {
        require(msg.sender == WETH, 'Transfer failed'); // only accept ETH via fallback from the WETH contract
    }


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
    ) external virtual override ensure(deadline) returns (uint256 index) {
        // create the pair if it doesn't exist yet
        if (IOSWAP_OracleFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IOSWAP_OracleFactory(factory).createPair(tokenA, tokenB);
        }
        address pair = pairFor(tokenA, tokenB);

        if (staked > 0)
            TransferHelper.safeTransferFrom(govToken, msg.sender, pair, staked);
        if (amountIn > 0)
            TransferHelper.safeTransferFrom(addingTokenA ? tokenA : tokenB, msg.sender, pair, amountIn);

        bool direction = (tokenA < tokenB) ? !addingTokenA : addingTokenA;
        (index) = IOSWAP_OraclePair(pair).addLiquidity(msg.sender, direction, staked, afterIndex, expire, enable);
    }
    function addLiquidityETH(
        address tokenA,
        bool addingTokenA,
        uint staked,
        uint afterIndex,
        uint amountAIn,
        uint expire,
        bool enable,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint index) {
        // create the pair if it doesn't exist yet
        if (IOSWAP_OracleFactory(factory).getPair(tokenA, WETH) == address(0)) {
            IOSWAP_OracleFactory(factory).createPair(tokenA, WETH);
        }
        uint ETHIn = msg.value;
        address pair = pairFor(tokenA, WETH);

        if (staked > 0)
            TransferHelper.safeTransferFrom(govToken, msg.sender, pair, staked);

        if (addingTokenA) {
            if (amountAIn > 0)
                TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountAIn);
        } else {
            IWETH(WETH).deposit{value: ETHIn}();
            require(IWETH(WETH).transfer(pair, ETHIn), 'Transfer failed');
        }
        bool direction = (tokenA < WETH) ? !addingTokenA : addingTokenA;
        (index) = IOSWAP_OraclePair(pair).addLiquidity(msg.sender, direction, staked, afterIndex, expire, enable);
    }

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
    ) public virtual override ensure(deadline) {
        address pair = pairFor(tokenA, tokenB);
        bool direction = (tokenA < tokenB) ? !removingTokenA : removingTokenA;
        IOSWAP_OraclePair(pair).removeLiquidity(msg.sender, direction, unstake, afterIndex, amountOut, reserveOut, expire, enable);
        
        if (unstake > 0)
            TransferHelper.safeTransfer(govToken, to, unstake);
        if (amountOut > 0 || reserveOut > 0) {
            address token = removingTokenA ? tokenA : tokenB;
            TransferHelper.safeTransfer(token, to, amountOut.add(reserveOut));
        }
    }
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
    ) public virtual override ensure(deadline) {
        address pair = pairFor(tokenA, WETH);
        bool direction = (tokenA < WETH) ? !removingTokenA : removingTokenA;
        IOSWAP_OraclePair(pair).removeLiquidity(msg.sender, direction, unstake, afterIndex, amountOut, reserveOut, expire, enable);

        if (unstake > 0)
            TransferHelper.safeTransfer(govToken, to, unstake);

        amountOut = amountOut.add(reserveOut);
        if (amountOut > 0) {
            if (removingTokenA) {
                TransferHelper.safeTransfer(tokenA, to, amountOut);
            } else {
                IWETH(WETH).withdraw(amountOut);
                TransferHelper.safeTransferETH(to, amountOut);
            }
        }
    }
    function removeAllLiquidity(
        address tokenA,
        address tokenB,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = pairFor(tokenA, tokenB);
        (uint256 amount0, uint256 amount1, uint256 staked) = IOSWAP_OraclePair(pair).removeAllLiquidity(msg.sender);
        (amountA, amountB) = (tokenA < tokenB) ? (amount0, amount1) : (amount1, amount0);
        TransferHelper.safeTransfer(tokenA, to, amountA);
        TransferHelper.safeTransfer(tokenB, to, amountB);
        TransferHelper.safeTransfer(govToken, to, staked);  
    }
    function removeAllLiquidityETH(
        address tokenA,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        address pair = pairFor(tokenA, WETH);
        (uint256 amount0, uint256 amount1, uint256 staked) = IOSWAP_OraclePair(pair).removeAllLiquidity(msg.sender);
        (amountToken, amountETH) = (tokenA < WETH) ? (amount0, amount1) : (amount1, amount0);
        TransferHelper.safeTransfer(tokenA, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
        TransferHelper.safeTransfer(govToken, to, staked);
    }

    // **** LIBRARY FUNCTIONS ****
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB) internal view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                /*oracle*/hex'f16ce672144451d138eed853d57e4616c66cace4e953a121899bbd6e5643ca03' // oracle init code hash
            ))));
    }
}