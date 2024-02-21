// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './IOSWAP_PausablePair.sol';

interface IOSWAP_PairBase is IOSWAP_PausablePair {
    function initialize(address toekn0, address toekn1) external;
}
