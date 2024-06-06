// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "../ERC1155Gateway.sol";
import "../interfaces/IMintBurn1155.sol";

contract ERC1155Gateway_MintBurn is ERC1155Gateway {

    constructor (address anyCallProxy, uint256 flag, address token) ERC1155Gateway(anyCallProxy, flag, token) {}

    function _swapout(address sender, uint256 tokenId, uint256 amount) internal override virtual returns (bool, bytes memory) {
        try IMintBurn1155(token).burn(sender, tokenId, amount) {
            return (true, "");
        } catch {
            return (false, "");
        }
    }

    function _swapin(uint256 tokenId, uint256 amount, address receiver, bytes memory extraMsg) internal override returns (bool) {
        try IMintBurn1155(token).mint(receiver, tokenId, amount) {
            return true;
        } catch {
            return false;
        }
    }
    
}