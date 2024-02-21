// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

interface IOSWAP_2Callee {
    function oswapdexCall(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
