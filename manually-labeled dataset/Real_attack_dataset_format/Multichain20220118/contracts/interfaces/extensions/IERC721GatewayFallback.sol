pragma solidity ^0.8.1;

import "../IERC721Gateway.sol";

interface IERC721GatewayFallback is IERC721Gateway {
    function Swapout(uint256 tokenId, address receiver, uint256 toChainID) external payable returns (uint256 swapoutSeq);
}