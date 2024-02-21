// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IBridgeToken {
    function burn(address from, uint256 amount) external;

    function mint(address to, uint256 amount) external;

    function updateTokenInfo(
        string calldata _newName,
        string calldata _newSymbol,
        uint8 _newDecimals
    ) external;
}
