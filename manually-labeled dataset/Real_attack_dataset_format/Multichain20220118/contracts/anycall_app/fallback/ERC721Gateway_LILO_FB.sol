// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "../ERC721Gateway_LILO.sol";
import "../../Address.sol";
import "../../interfaces/IGatewayClient721.sol";
import "../../extensions/ERC721GatewayFallback.sol";


contract ERC721Gateway_LILO_FB is ERC721Gateway_LILO, ERC721GatewayFallback {
    using Address for address;

    constructor (address anyCallProxy, uint256 flag, address token) ERC721Gateway_LILO(anyCallProxy, flag, token) {}
    
    function _swapoutFallback(uint256 tokenId, address sender, uint256 swapoutSeq, bytes memory extraMsg) internal override returns (bool result) {
        try IERC721(token).safeTransferFrom(address(this), msg.sender, tokenId)  {
            result = true;
        } catch {
            result = false;
        }
        if (sender.isContract()) {
            bytes memory _data = abi.encodeWithSelector(IGatewayClient721.notifySwapoutFallback.selector, result, tokenId, swapoutSeq);
            sender.call(_data);
        }
        return result;
    }
}