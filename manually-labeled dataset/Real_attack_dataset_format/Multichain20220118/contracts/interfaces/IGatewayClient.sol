pragma solidity ^0.8.1;
interface IGatewayClient {
    function notifySwapoutFallback(bool refundSuccess, uint256 amount, uint256 swapoutSeq) external returns (bool);
}