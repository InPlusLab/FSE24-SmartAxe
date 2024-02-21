// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface I_TrollNFT is IERC721 {
    function stakingBalance(uint256 tokenId) external view returns (uint256 stakes);
    function lastStakeDate(uint256 tokenId) external view returns (uint256 timestamp);
    function addStakes(uint256 tokenId, uint256 amount) external;
}