// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >= 0.8.6;

import "./IOSWAP_BridgeVault.sol";

interface IOSWAP_SwapPolicy {

    function allowToSwap(IOSWAP_BridgeVault.Order calldata order) external view returns (bool isAllow);
}