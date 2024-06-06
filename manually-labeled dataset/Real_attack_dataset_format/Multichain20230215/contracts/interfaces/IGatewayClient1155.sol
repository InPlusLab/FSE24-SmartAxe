pragma solidity ^0.8.1;

interface IGatewayClient1155 {
    function notifySwapoutFallback(bool refundSuccess, uint256 tokenId, uint256 amount, uint256 swapoutSeq) external returns (bool);
}