// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IBridgeRouter {
    // enter amount of tokens to protocol
    function enter(
        address token,
        uint256 amount,
        uint256 targetChainId
    ) external;

    // enter amount of system currency to protocol
    function enterETH(uint256 targetChainId) external payable;

    // exit amount of tokens from protocol
    function exit(bytes calldata data, bytes[] calldata signatures) external;
}
