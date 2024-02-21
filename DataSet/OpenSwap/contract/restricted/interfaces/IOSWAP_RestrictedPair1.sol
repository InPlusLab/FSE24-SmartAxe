
// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './IOSWAP_RestrictedPair.sol';

interface IOSWAP_RestrictedPair1 is IOSWAP_RestrictedPair {
    event AddLiquidity(address indexed provider, bool indexed direction, uint256 indexed index, uint256 amount, uint256 newAmountBalance);
    event RemoveLiquidity(address indexed provider, bool indexed direction, uint256 indexed index, uint256 amountOut, uint256 receivingOut, uint256 newAmountBalance, uint256 newReceivingBalance);

    // function createOrder(address provider, bool direction, bool allowAll, uint256 restrictedPrice, uint256 startDate, uint256 expire) external returns (uint256 index);

    function addLiquidity(bool direction, uint256 index) external;
    function removeLiquidity(address provider, bool direction, uint256 index, uint256 amountOut, uint256 receivingOut) external;
    function removeAllLiquidity(address provider) external returns (uint256 amount0, uint256 amount1);
    function removeAllLiquidity1D(address provider, bool direction) external returns (uint256 totalAmount, uint256 totalReceiving);

    function setApprovedTrader(bool direction, uint256 offerIndex, address trader, uint256 allocation) external;
    function setMultipleApprovedTraders(bool direction, uint256 offerIndex, address[] calldata trader, uint256[] calldata allocation) external;
}