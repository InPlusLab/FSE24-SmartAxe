pragma solidity ^0.8.1;

import "../IERC20Gateway.sol";

interface IERC20GatewayFallback is IERC20Gateway {
    function Swapout(uint256 amount, address receiver, uint256 toChainID) external payable returns (uint256 swapoutSeq);
}