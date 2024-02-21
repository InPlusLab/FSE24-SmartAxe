// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./EIP712MetaTransaction.sol";
import "./ISolarRouter.sol";
import "./IToken.sol";

contract MockRouter {
    function swapExactTokensForETH(
        uint256,
        uint256,
        address[] calldata,
        address,
        uint256
    ) external virtual returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = 0;
        return amounts;
    }
}
