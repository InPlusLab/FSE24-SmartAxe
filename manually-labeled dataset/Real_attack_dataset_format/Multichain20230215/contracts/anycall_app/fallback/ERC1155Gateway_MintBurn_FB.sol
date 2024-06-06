// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "../ERC1155Gateway_MintBurn.sol";
import "../../Address.sol";
import "../../interfaces/IGatewayClient1155.sol";
import "../../extensions/ERC1155GatewayFallback.sol";


contract ERC1155Gateway_MintBurn_FB is ERC1155Gateway_MintBurn, ERC1155GatewayFallback{
    using Address for address;
    
    constructor (address anyCallProxy, uint256 flag, address token) ERC1155Gateway_MintBurn(anyCallProxy, flag, token) {}

    function _swapoutFallback(uint256 tokenId, uint256 amount, address sender, uint256 swapoutSeq, bytes memory extraMsg) internal override returns (bool result) {
        try IMintBurn1155(token).mint(sender, tokenId, amount) {
            result = true;
        } catch {
            result = false;
        }
        if (sender.isContract()) {
            bytes memory _data = abi.encodeWithSelector(IGatewayClient1155.notifySwapoutFallback.selector, result, tokenId, amount, swapoutSeq);
            sender.call(_data);
        }
        return result;
    }
}