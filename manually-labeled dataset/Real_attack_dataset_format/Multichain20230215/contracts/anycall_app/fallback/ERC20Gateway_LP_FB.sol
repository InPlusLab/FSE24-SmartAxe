// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "../ERC20Gateway_LP.sol";
import "../../Address.sol";
import "../../interfaces/IGatewayClient.sol";
import "../../extensions/ERC20GatewayFallback.sol";


contract ERC20Gateway_LP_FB is ERC20Gateway_LP, ERC20GatewayFallback {
    using Address for address;

    constructor (address anyCallProxy, uint256 flag, address token) ERC20Gateway_LP(anyCallProxy, flag, token) {}

    function _swapoutFallback(uint256 amount, address sender, uint256 swapoutSeq) internal override returns (bool result) {
        result = ITransfer(token).transferFrom(address(this), sender, amount);
        if (sender.isContract()) {
            bytes memory _data = abi.encodeWithSelector(IGatewayClient.notifySwapoutFallback.selector, result, amount, swapoutSeq);
            sender.call(_data);
        }
        return result;
    }
}