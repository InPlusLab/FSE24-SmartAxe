pragma solidity ^0.8.1;

interface IGatewayClient721 {
    function notifySwapoutFallback(bool refundSuccess, uint256 tokenId, uint256 swapoutSeq) external returns (bool);
}