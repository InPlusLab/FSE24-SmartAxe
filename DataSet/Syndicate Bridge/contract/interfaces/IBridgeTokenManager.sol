// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../library/RToken.sol";

interface IBridgeTokenManager {
    event TokenAdded(address indexed addr, uint256 chainId);
    event TokenRemoved(address indexed addr, uint256 chainId);

    function issue(
        address[] calldata tokens,
        RToken.IssueType[] calldata issueTypes,
        uint256 targetChainId
    ) external;

    function revoke(address targetAddr) external;

    function getLocal(address sourceAddr, uint256 targetChainId)
        external
        view
        returns (RToken.Token memory token);

    function isZero(uint256 targetChainId) external view returns (bool);
}
