// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './interfaces/IOSWAP_RestrictedPair1.sol';
import './interfaces/IOSWAP_RestrictedFactory.sol';
import './interfaces/IOSWAP_ConfigStore.sol';
import './OSWAP_RestrictedPair.sol';

contract OSWAP_RestrictedPair1 is IOSWAP_RestrictedPair1, OSWAP_RestrictedPair {

    function addLiquidity(bool direction, uint256 index) external override lock {
        require(IOSWAP_RestrictedFactory(factory).isLive(), 'GLOBALLY PAUSED');
        require(isLive, "PAUSED");
        Offer storage offer = offers[direction][index];
        require(msg.sender == restrictedLiquidityProvider || msg.sender == offer.provider, "Not from router or owner");

        (uint256 newGovBalance, uint256 newToken0Balance, uint256 newToken1Balance) = getBalances();

        uint256 amountIn;
        if (direction) {
            amountIn = newToken1Balance.sub(lastToken1Balance);
        } else {
            amountIn = newToken0Balance.sub(lastToken0Balance);
        }
        require(amountIn > 0, "No amount in");

        offer.amount = offer.amount.add(amountIn);

        lastGovBalance = newGovBalance;
        lastToken0Balance = newToken0Balance;
        lastToken1Balance = newToken1Balance;

        emit AddLiquidity(offer.provider, direction, index, amountIn, offer.amount);
    }

    function removeLiquidity(address provider, bool direction, uint256 index, uint256 amountOut, uint256 receivingOut) external override lock {
        require(msg.sender == restrictedLiquidityProvider || msg.sender == provider, "Not from router or owner");
        _removeLiquidity(provider, direction, index, amountOut, receivingOut);
        (address tokenA, address tokenB) = direction ? (token1,token0) : (token0,token1);
        _safeTransfer(tokenA, msg.sender, amountOut); // optimistically transfer tokens
        _safeTransfer(tokenB, msg.sender, receivingOut); // optimistically transfer tokens
        _sync();
    }
    function removeAllLiquidity(address provider) external override lock returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _removeAllLiquidity1D(provider, false);
        (uint256 amount2, uint256 amount3) = _removeAllLiquidity1D(provider, true);
        amount0 = amount0.add(amount3);
        amount1 = amount1.add(amount2);
    }
    function removeAllLiquidity1D(address provider, bool direction) external override lock returns (uint256 totalAmount, uint256 totalReceiving) {
        return _removeAllLiquidity1D(provider, direction);
    }
    function _removeAllLiquidity1D(address provider, bool direction) internal returns (uint256 totalAmount, uint256 totalReceiving) {
        require(msg.sender == restrictedLiquidityProvider || msg.sender == provider, "Not from router or owner");
        uint256[] storage list = providerOfferIndex[direction][provider];
        uint256 length =  list.length;
        for (uint256 i = 0 ; i < length ; i++) {
            uint256 index = list[i];
            Offer storage offer = offers[direction][index]; 
            totalAmount = totalAmount.add(offer.amount);
            totalReceiving = totalReceiving.add(offer.receiving);
            _removeLiquidity(provider, direction, index, offer.amount, offer.receiving);
        }
        (uint256 amount0, uint256 amount1) = direction ? (totalReceiving, totalAmount) : (totalAmount, totalReceiving);
        _safeTransfer(token0, msg.sender, amount0); // optimistically transfer tokens
        _safeTransfer(token1, msg.sender, amount1); // optimistically transfer tokens
        _sync();
    }
    function _removeLiquidity(address provider, bool direction, uint256 index, uint256 amountOut, uint256 receivingOut) internal {
        require(index > 0, "Provider liquidity not found");

        Offer storage offer = offers[direction][index]; 
        require(offer.provider == provider, "Not from provider");

        if (offer.locked && amountOut > 0) {
            require(offer.expire < block.timestamp, "Not expired");
        }

        offer.amount = offer.amount.sub(amountOut);
        offer.receiving = offer.receiving.sub(receivingOut);

        emit RemoveLiquidity(provider, direction, index, amountOut, receivingOut, offer.amount, offer.receiving);
    }

    function _checkApprovedTrader(bool direction, uint256 offerIndex, uint256 count) internal {
        Offer storage offer = offers[direction][offerIndex]; 
        require(msg.sender == restrictedLiquidityProvider || msg.sender == offer.provider, "Not from router or owner");
        require(!offer.locked, "Offer locked");
        require(!offer.allowAll, "Offer was set to allow all");
        uint256 feePerTrader = uint256(IOSWAP_ConfigStore(configStore).customParam(FEE_PER_TRADER));
        _collectFee(offer.provider, feePerTrader.mul(count));
    }
    function setApprovedTrader(bool direction, uint256 offerIndex, address trader, uint256 allocation) external override {
        _checkApprovedTrader(direction, offerIndex, 1);
        _setApprovedTrader(direction, offerIndex, trader, allocation);
    }
    function setMultipleApprovedTraders(bool direction, uint256 offerIndex, address[] calldata trader, uint256[] calldata allocation) external override {
        uint256 length = trader.length;
        require(length == allocation.length, "length not match");
        _checkApprovedTrader(direction, offerIndex, length);
        for (uint256 i = 0 ; i < length ; i++) {
            _setApprovedTrader(direction, offerIndex, trader[i], allocation[i]);
        }
    }
}