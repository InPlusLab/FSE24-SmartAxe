pragma solidity ^0.8.1;

import "../AnyCallAppFallback.sol";
import "../ERC1155Gateway.sol";
import "../interfaces/extensions/IERC1155GatewayFallback.sol";

abstract contract ERC1155GatewayFallback is ERC1155Gateway, AnyCallAppFallback, IERC1155GatewayFallback {

    function _swapoutFallback(uint256 tokenId, uint256 amount, address sender, uint256 swapoutSeq, bytes memory extraMsg) internal virtual returns (bool);

    function Swapout(uint256 tokenId, uint256 amount, address receiver, uint256 destChainID) external payable returns (uint256) {
        (bool ok, bytes memory extraMsg) = _swapout(msg.sender, tokenId, amount);
        require(ok);
        swapoutSeq++;
        bytes memory data = abi.encode(tokenId, amount, msg.sender, receiver, swapoutSeq, extraMsg);
        _anyCall(peer[destChainID], data, address(this), destChainID);
        emit LogAnySwapOut(tokenId, msg.sender, receiver, destChainID, swapoutSeq);
        return swapoutSeq;
    }

    function _anyFallback(bytes calldata data) internal override {
        (uint256 tokenId, uint256 amount, address sender, , uint256 swapoutSeq, bytes memory extraMsg) = abi.decode(
            data,
            (uint256, uint256, address, address, uint256, bytes)
        );
        require(_swapoutFallback(tokenId, amount, sender, swapoutSeq, extraMsg));
    }
}