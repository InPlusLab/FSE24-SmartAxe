// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface ILBPair {
  function tokenX() external view returns (address);

  function tokenY() external view returns (address);

  function getReservesAndId() external view returns (uint256 reserveX, uint256 reserveY, uint256 activeId);
}
