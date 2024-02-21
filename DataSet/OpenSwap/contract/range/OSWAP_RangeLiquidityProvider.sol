// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './interfaces/IOSWAP_RangeLiquidityProvider.sol';
import './interfaces/IOSWAP_RangePair.sol';
import './OSWAP_RangePair.sol';
import './interfaces/IOSWAP_RangeFactory.sol';
import '../gov/interfaces/IOAXDEX_Governance.sol';
import '../libraries/TransferHelper.sol';
import '../libraries/SafeMath.sol';
import '../interfaces/IWETH.sol';

contract OSWAP_RangeLiquidityProvider is IOSWAP_RangeLiquidityProvider {
    using SafeMath for uint256;

    address public immutable override factory;
    address public immutable override WETH;
    address public immutable override govToken;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, 'EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
        govToken = IOAXDEX_Governance(IOSWAP_RangeFactory(_factory).governance()).oaxToken();
    }
    
    receive() external payable {
        require(msg.sender == WETH, 'Transfer failed'); // only accept ETH via fallback from the WETH contract
    }


    // **** ADD LIQUIDITY ****
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool addingTokenA,
        uint256 staked,
        uint256 amountIn,
        uint256 lowerLimit, 
        uint256 upperLimit,
        uint256 startDate,
        uint256 expire,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256 index) {
        // create the pair if it doesn't exist yet
        if (IOSWAP_RangeFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IOSWAP_RangeFactory(factory).createPair(tokenA, tokenB);
        }
        address pair = pairFor(tokenA, tokenB);

        if (staked > 0)
            TransferHelper.safeTransferFrom(govToken, msg.sender, pair, staked);
        if (amountIn > 0)
            TransferHelper.safeTransferFrom(addingTokenA ? tokenA : tokenB, msg.sender, pair, amountIn);

        bool direction = (tokenA < tokenB) ? !addingTokenA : addingTokenA;
        index = IOSWAP_RangePair(pair).addLiquidity(msg.sender, direction, staked, lowerLimit, upperLimit, startDate, expire);
    }
    function addLiquidityETH(
        address tokenA,
        bool addingTokenA,
        uint256 staked,
        uint256 amountAIn,
        uint256 lowerLimit, 
        uint256 upperLimit,
        uint256 startDate,
        uint256 expire,
        uint256 deadline
    ) external virtual override payable ensure(deadline) returns (uint256 index) {
        // create the pair if it doesn't exist yet
        if (IOSWAP_RangeFactory(factory).getPair(tokenA, WETH) == address(0)) {
            IOSWAP_RangeFactory(factory).createPair(tokenA, WETH);
        }
        uint256 ETHIn = msg.value;
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
        index = IOSWAP_RangePair(pair).addLiquidity(msg.sender, direction, staked, lowerLimit, upperLimit, startDate, expire);
    }

    function updateProviderOffer(
        address tokenA, 
        address tokenB, 
        uint256 replenishAmount, 
        uint256 lowerLimit, 
        uint256 upperLimit, 
        uint256 startDate,
        uint256 expire, 
        bool privateReplenish, 
        uint256 deadline
    ) external override ensure(deadline) {
        address pair = pairFor(tokenA, tokenB);
        bool direction = (tokenA < tokenB);
        IOSWAP_RangePair(pair).updateProviderOffer(msg.sender, direction, replenishAmount, lowerLimit, upperLimit, startDate, expire, privateReplenish);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool removingTokenA,
        address to,
        uint256 unstake,
        uint256 amountOut,
        uint256 reserveOut,
        uint256 lowerLimit, 
        uint256 upperLimit,
        uint256 startDate,
        uint256 expire,
        uint256 deadline
    ) public virtual override ensure(deadline) {
        address pair = pairFor(tokenA, tokenB);
        bool direction = (tokenA < tokenB) ? !removingTokenA : removingTokenA;
        IOSWAP_RangePair(pair).removeLiquidity(msg.sender, direction, unstake, amountOut, reserveOut, lowerLimit, upperLimit, startDate, expire);


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
        uint256 unstake,
        uint256 amountOut,
        uint256 reserveOut,
        uint256 lowerLimit, 
        uint256 upperLimit,
        uint256 startDate,
        uint256 expire,
        uint256 deadline
    ) public virtual override ensure(deadline) {
        address pair = pairFor(tokenA, WETH);
        bool direction = (tokenA < WETH) ? !removingTokenA : removingTokenA;
        IOSWAP_RangePair(pair).removeLiquidity(msg.sender, direction, unstake, amountOut, reserveOut, lowerLimit, upperLimit, startDate, expire);

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
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = pairFor(tokenA, tokenB);
        (uint256 amount0, uint256 amount1, uint256 staked) = IOSWAP_RangePair(pair).removeAllLiquidity(msg.sender);
        (amountA, amountB) = (tokenA < tokenB) ? (amount0, amount1) : (amount1, amount0);
        TransferHelper.safeTransfer(tokenA, to, amountA);
        TransferHelper.safeTransfer(tokenB, to, amountB);
        TransferHelper.safeTransfer(govToken, to, staked);
    }
    function removeAllLiquidityETH(
        address tokenA,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
        address pair = pairFor(tokenA, WETH);
        (uint256 amount0, uint256 amount1, uint256 staked) = IOSWAP_RangePair(pair).removeAllLiquidity(msg.sender);
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
        pair = address(uint256(keccak256(abi.encodePacked(
                hex'ff',    
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                /*range*/hex'78dc6857442275f34e463f5001ada900e5a91ee4b7a78bf96df0472429dae422' // range init code hash
            ))));
    }
}