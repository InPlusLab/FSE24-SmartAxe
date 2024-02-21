// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './IOSWAP_RestrictedPairPrepaidFee.sol';

interface IOSWAP_RestrictedPair3 is IOSWAP_RestrictedPairPrepaidFee {
    function allocationSet(bool direction, uint256 offerIndex, address trader) external view returns (bool isSet);
    function setApprovedTraderBySignature(bool direction, uint256 offerIndex, address trader, uint256 allocation, bytes calldata signature) external;
}