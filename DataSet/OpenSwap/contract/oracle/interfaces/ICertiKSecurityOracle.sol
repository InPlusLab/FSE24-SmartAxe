// SPDX-License-Identifier: MIT
pragma solidity =0.6.11;

interface ICertiKSecurityOracle {
  function getSecurityScoreBytes4(address contractAddress, bytes4 functionSignature) external view returns (uint8);
  function getSecurityScore(address contractAddress, string memory functionSignature) external view returns (uint8);
  function getSecurityScore(address contractAddress) external view returns (uint8);
  function getSecurityScores(address[] memory addresses,bytes4[] memory functionSignatures) external view returns (uint8[] memory);
}