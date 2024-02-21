// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './interfaces/IOSWAP_RestrictedPairPrepaidFee.sol';
import './interfaces/IOSWAP_RestrictedFactory.sol';
import './OSWAP_RestrictedPair.sol';

abstract contract OSWAP_RestrictedPairPrepaidFee is IOSWAP_RestrictedPairPrepaidFee, OSWAP_RestrictedPair {
    mapping(bool => mapping(uint256 => uint256)) public override prepaidFeeBalance;

    function addLiquidity(bool direction, uint256 index, uint256 feeIn) external override lock {
        require(IOSWAP_RestrictedFactory(factory).isLive(), 'GLOBALLY PAUSED');
        require(isLive, "PAUSED");
        Offer storage offer = offers[direction][index];
        require(msg.sender == restrictedLiquidityProvider || msg.sender == offer.provider, "Not from router or owner");

        (uint256 newGovBalance, uint256 newToken0Balance, uint256 newToken1Balance) = getBalances();
        require(newGovBalance.sub(lastGovBalance) >= feeIn, "Invalid feeIn");
        uint256 newFeeBalance = prepaidFeeBalance[direction][index].add(feeIn);
        prepaidFeeBalance[direction][index] = newFeeBalance;

        uint256 amountIn;
        if (direction) {
            amountIn = newToken1Balance.sub(lastToken1Balance);
            if (govToken == token1)
                amountIn = amountIn.sub(feeIn);
        } else {
            amountIn = newToken0Balance.sub(lastToken0Balance);
            if (govToken == token0)
                amountIn = amountIn.sub(feeIn);
        }
        require(amountIn > 0 || feeIn > 0, "No amount in");

        offer.amount = offer.amount.add(amountIn);

        lastGovBalance = newGovBalance;
        lastToken0Balance = newToken0Balance;
        lastToken1Balance = newToken1Balance;

        emit AddLiquidity(offer.provider, direction, index, amountIn, offer.amount, feeIn, newFeeBalance);
    }


    function removeLiquidity(address provider, bool direction, uint256 index, uint256 amountOut, uint256 receivingOut, uint256 feeOut) external override lock {
        require(msg.sender == restrictedLiquidityProvider || msg.sender == provider, "Not from router or owner");
        _removeLiquidity(provider, direction, index, amountOut, receivingOut, feeOut);
        (address tokenA, address tokenB) = direction ? (token1,token0) : (token0,token1);
        _safeTransfer(tokenA, msg.sender, amountOut); // optimistically transfer tokens
        _safeTransfer(tokenB, msg.sender, receivingOut); // optimistically transfer tokens
        _safeTransfer(govToken, msg.sender, feeOut); // optimistically transfer tokens
        _sync();
    }
    function removeAllLiquidity(address provider) external override lock returns (uint256 amount0, uint256 amount1, uint256 feeOut) {
        (amount0, amount1, feeOut) = _removeAllLiquidity1D(provider, false);
        (uint256 amount2, uint256 amount3, uint256 feeOut2) = _removeAllLiquidity1D(provider, true);
        amount0 = amount0.add(amount3);
        amount1 = amount1.add(amount2);
        feeOut = feeOut.add(feeOut2);
    }
    function removeAllLiquidity1D(address provider, bool direction) external override lock returns (uint256 totalAmount, uint256 totalReceiving, uint256 totalRemainingFee) {
        return _removeAllLiquidity1D(provider, direction);
    }
    function _removeAllLiquidity1D(address provider, bool direction) internal returns (uint256 totalAmount, uint256 totalReceiving, uint256 totalRemainingFee) {
        require(msg.sender == restrictedLiquidityProvider || msg.sender == provider, "Not from router or owner");
        uint256[] storage list = providerOfferIndex[direction][provider];
        uint256 length =  list.length;
        for (uint256 i = 0 ; i < length ; i++) {
            uint256 index = list[i];
            Offer storage offer = offers[direction][index]; 
            totalAmount = totalAmount.add(offer.amount);
            totalReceiving = totalReceiving.add(offer.receiving);
            uint256 feeBalance = prepaidFeeBalance[direction][index];
            totalRemainingFee = totalRemainingFee.add(feeBalance);
            _removeLiquidity(provider, direction, index, offer.amount, offer.receiving, feeBalance);
        }
        (uint256 amount0, uint256 amount1) = direction ? (totalReceiving, totalAmount) : (totalAmount, totalReceiving);
        _safeTransfer(token0, msg.sender, amount0); // optimistically transfer tokens
        _safeTransfer(token1, msg.sender, amount1); // optimistically transfer tokens
        _safeTransfer(govToken, msg.sender, totalRemainingFee); // optimistically transfer tokens
        _sync();
    }
    function _removeLiquidity(address provider, bool direction, uint256 index, uint256 amountOut, uint256 receivingOut, uint256 feeOut) internal {
        require(index > 0, "Provider liquidity not found");

        Offer storage offer = offers[direction][index]; 
        require(offer.provider == provider, "Not from provider");

        if (offer.locked && amountOut > 0) {
            require(offer.expire < block.timestamp, "Not expired");
        }

        offer.amount = offer.amount.sub(amountOut);
        offer.receiving = offer.receiving.sub(receivingOut);
        uint256 newFeeBalance = prepaidFeeBalance[direction][index].sub(feeOut);
        prepaidFeeBalance[direction][index] = newFeeBalance;

        emit RemoveLiquidity(provider, direction, index, amountOut, receivingOut, feeOut, offer.amount, offer.receiving, newFeeBalance);
    }


}