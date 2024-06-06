pragma solidity ^0.8.1;

import "../IERC1155Gateway.sol";

interface IERC1155GatewayFallback is IERC1155Gateway {
    function Swapout(uint256 tokenId, uint256 amount, address receiver, uint256 toChainID) external payable returns (uint256 swapoutSeq);
}