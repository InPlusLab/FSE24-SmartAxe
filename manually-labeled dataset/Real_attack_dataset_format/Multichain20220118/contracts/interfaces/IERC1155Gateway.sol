pragma solidity ^0.8.1;
interface IERC1155Gateway {
    function token() external view returns (address);
    function Swapout_no_fallback(uint256 tokenId, uint256 amount, address receiver, uint256 toChainID) external payable returns (uint256 swapoutSeq);
}