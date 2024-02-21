// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.0;

import "../metarouter/MetaRouteStructs.sol";
import "../Portal.sol";

interface IPortal {
    function getChainId() external view returns (uint256);

    function synthesize(
        uint256 _stableBridgingFee,
        address _token,
        uint256 _amount,
        address _chain2address,
        address _receiveSide,
        address _oppositeBridge,
        address _revertableAddress,
        uint256 _chainID,
        bytes32 _clientID
    ) external returns (bytes32);

    function metaSynthesize(
        MetaRouteStructs.MetaSynthesizeTransaction
            memory _metaSynthesizeTransaction
    ) external returns (bytes32);

    function synthesizeNative(
        uint256 _stableBridgingFee,
        address _chain2address,
        address _receiveSide,
        address _oppositeBridge,
        address _revertableAddress,
        uint256 _chainID,
        bytes32 _clientID
    ) external payable returns (bytes32);

    function synthesizeWithPermit(
        Portal.SynthesizeWithPermitTransaction memory _syntWithPermit
    ) external returns (bytes32);

    function revertSynthesize(uint256 _stableBridgingFee, bytes32 _externalID) external;

    function unsynthesize(
        uint256 _stableBridgingFee,
        bytes32 _externalID,
        address _token,
        uint256 _amount,
        address _to
    ) external;

    function revertBurnRequest(
        uint256 _stableBridgingFee,
        bytes32 _internalID,
        address _receiveSide,
        address _oppositeBridge,
        uint256 _chainId,
        bytes32 _clientID
    ) external;
}
