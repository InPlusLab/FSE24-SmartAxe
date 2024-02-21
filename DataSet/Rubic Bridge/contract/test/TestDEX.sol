// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface ITestDEX {
    function swap(
        address _fromToken,
        uint256 _inputAmount,
        address _toToken
    ) external;
}

contract TestDEX is ITestDEX {
    uint256 public constant price = 2;

    function swap(
        address _fromToken,
        uint256 _inputAmount,
        address _toToken
    ) external override {
        IERC20(_fromToken).transferFrom(
            msg.sender,
            address(this),
            _inputAmount
        );
        IERC20(_toToken).transfer(
            msg.sender,
            _inputAmount * price
        );
    }
}
