// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "../ERC20Gateway.sol";
import "../interfaces/IAnyERC20_legacy.sol";

contract ERC20Gateway_for_AnyERC20_legacy is ERC20Gateway {

    constructor (address anyCallProxy, uint256 flag, address token) ERC20Gateway(anyCallProxy, flag, token) {}

    function _swapout(uint256 amount, address sender) internal override returns (bool) {
        return IAnyERC20_legacy(token).Swapout(amount, address(0));
    }

    function _swapin(uint256 amount, address receiver) internal override returns (bool) {
        return IAnyERC20_legacy(token).Swapin(bytes32(bytes("")), receiver, amount);
    }

}