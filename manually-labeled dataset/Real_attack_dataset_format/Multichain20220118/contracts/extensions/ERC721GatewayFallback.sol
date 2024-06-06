pragma solidity ^0.8.1;

import "../AnyCallAppFallback.sol";
import "../ERC721Gateway.sol";
import "../interfaces/extensions/IERC721GatewayFallback.sol";

abstract contract ERC721GatewayFallback is ERC721Gateway, AnyCallAppFallback, IERC721GatewayFallback {

    function _swapoutFallback(uint256 tokenId, address sender, uint256 swapoutSeq, bytes memory extraMsg) internal virtual returns (bool);

    function Swapout(uint256 tokenId, address receiver, uint256 destChainID) external payable returns (uint256) {
        (bool ok, bytes memory extraMsg) = _swapout(tokenId);
        require(ok);
        swapoutSeq++;
        bytes memory data = abi.encode(tokenId, msg.sender, receiver, swapoutSeq, extraMsg);
        _anyCall(peer[destChainID], data, address(this), destChainID);
        emit LogAnySwapOut(tokenId, msg.sender, receiver, destChainID, swapoutSeq);
        return swapoutSeq;
    }

    function _anyFallback(bytes calldata data) internal override {
        (uint256 tokenId, address sender, , uint256 swapoutSeq, bytes memory extraMsg) = abi.decode(
            data,
            (uint256, address, address, uint256, bytes)
        );
        require(_swapoutFallback(tokenId, sender, swapoutSeq, extraMsg));
    }
}