// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "../ERC20Gateway.sol";
import "../interfaces/IMintBurn.sol";

contract ERC20Gateway_MintBurn is ERC20Gateway {

    constructor(address anyCallProxy, uint256 flag, address token) ERC20Gateway(anyCallProxy, flag, token) {}

    function _swapout(uint256 amount, address sender) internal override returns (bool) {
        try IMintBurn(token).burnFrom(sender, amount) {
            return true;
        } catch {
            return false;
        }
    }

    function _swapin(uint256 amount, address receiver) internal override returns (bool) {
        try IMintBurn(token).mint(receiver, amount) {
            return true;
        } catch {
            return false;
        }
    }

}
