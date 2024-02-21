// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

interface IOSWAP_PairCreator {
    function createPair(bytes32 salt) external returns (address);
}
