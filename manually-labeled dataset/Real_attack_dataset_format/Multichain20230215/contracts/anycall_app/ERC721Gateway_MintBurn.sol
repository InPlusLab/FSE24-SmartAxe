// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "../ERC721Gateway.sol";
import "../interfaces/IMintBurn721.sol";

contract ERC721Gateway_MintBurn is ERC721Gateway {

    constructor (address anyCallProxy, uint256 flag, address token) ERC721Gateway(anyCallProxy, flag, token) {}

    function _swapout(uint256 tokenId) internal override virtual returns (bool, bytes memory) {
        require(IMintBurn721(token).ownerOf(tokenId) == msg.sender, "not allowed");
        try IMintBurn721(token).burn(tokenId) {
            return (true, "");
        } catch {
            return (false, "");
        }
    }

    function _swapin(uint256 tokenId, address receiver, bytes memory extraMsg) internal override returns (bool) {
        try IMintBurn721(token).mint(receiver, tokenId) {
            return true;
        } catch {
            return false;
        }
    }
    
}