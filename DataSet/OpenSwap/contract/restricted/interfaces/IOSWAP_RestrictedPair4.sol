// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './IOSWAP_RestrictedPairPrepaidFee.sol';

interface IOSWAP_RestrictedPair4 is IOSWAP_RestrictedPairPrepaidFee {

    event MerkleRoot(address indexed provider, bool indexed direction, uint256 index, bytes32 merkleRoot, string ipfsCid);

    function lastTraderAllocation(bool direction, uint256 offerIndex, address trader) external view returns (uint256 lastAllocation);
    function offerMerkleRoot(bool direction, uint256 i) external view returns (bytes32 root);
    function offerAllowlistIpfsCid(bool direction, uint256 i) external view returns (string memory ipfsCid);
    function setMerkleRoot(bool direction, uint256 index, bytes32 merkleRoot, string calldata ipfsCid) external ;
    function setApprovedTraderByMerkleProof(bool direction, uint256 offerIndex, address trader, uint256 allocation, bytes32[] calldata proof) external;
}