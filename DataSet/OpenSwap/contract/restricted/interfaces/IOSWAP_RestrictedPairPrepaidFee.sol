// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './IOSWAP_RestrictedPair.sol';

interface IOSWAP_RestrictedPairPrepaidFee is IOSWAP_RestrictedPair {

    event AddLiquidity(address indexed provider, bool indexed direction, uint256 indexed index, uint256 amount, uint256 newAmountBalance, uint256 feeIn, uint256 newFeeBalance);
    event RemoveLiquidity(address indexed provider, bool indexed direction, uint256 indexed index, uint256 amountOut, uint256 receivingOut, uint256 feeOut, uint256 newAmountBalance, uint256 newReceivingBalance, uint256 newFeeBalance);

    function prepaidFeeBalance(bool direction, uint256 i) external view returns (uint balance);

    function addLiquidity(bool direction, uint256 index, uint256 feeIn) external;
    function removeLiquidity(address provider, bool direction, uint256 index, uint256 amountOut, uint256 receivingOut, uint256 feeOut) external;
    function removeAllLiquidity(address provider) external returns (uint256 amount0, uint256 amount1, uint256 feeOut);
    function removeAllLiquidity1D(address provider, bool direction) external returns (uint256 totalAmount, uint256 totalReceiving, uint256 totalRemainingFee);
 
}