// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.0;

import "../metarouter/MetaRouteStructs.sol";

interface ISynthesis {
  function mintSyntheticToken(
    uint256 _stableBridgingFee,
    bytes32 _externalID,
    address _tokenReal,
    uint256 _chainID,
    uint256 _amount,
    address _to
  ) external;

  function revertSynthesizeRequest(
    uint256 _stableBridgingFee,
    bytes32 _internalID,
    address _receiveSide,
    address _oppositeBridge,
    uint256 _chainID,
    bytes32 _clientID
  ) external;

  function burnSyntheticToken(
    uint256 _stableBridgingFee,
    address _stoken,
    uint256 _amount,
    address _chain2address,
    address _receiveSide,
    address _oppositeBridge,
    address _revertableAddress,
    uint256 _chainID,
    bytes32 _clientID
  ) external returns (bytes32 internalID);

  function metaBurnSyntheticToken(
    MetaRouteStructs.MetaBurnTransaction memory _metaBurnTransaction
  ) external returns (bytes32 internalID);

  function revertBurn(uint256 _stableBridgingFee, bytes32 _externalID) external;
}
