// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './interfaces/IOSWAP_RestrictedPair4.sol';
import './interfaces/IOSWAP_ConfigStore.sol';
import './OSWAP_RestrictedPairPrepaidFee.sol';
import './MerkleProof.sol';

// traders set their own allocation from merkle tree proof
contract OSWAP_RestrictedPair4 is IOSWAP_RestrictedPair4, OSWAP_RestrictedPairPrepaidFee {

    mapping(bool => mapping(uint256 => mapping(address => uint256))) public override lastTraderAllocation;
    mapping(bool => mapping(uint256 => bytes32)) public override offerMerkleRoot;
    mapping(bool => mapping(uint256 => string)) public override offerAllowlistIpfsCid;

    function setMerkleRoot(bool direction, uint256 index, bytes32 merkleRoot, string calldata ipfsCid) external override lock {
        if (merkleRoot != offerMerkleRoot[direction][index]) {
            Offer storage offer = offers[direction][index];
            require(msg.sender == restrictedLiquidityProvider || msg.sender == offer.provider, "not from provider");
            require(!offer.locked, "offer locked");
            offerMerkleRoot[direction][index] = merkleRoot;
            offerAllowlistIpfsCid[direction][index] = ipfsCid;
            emit MerkleRoot(offer.provider, direction, index, merkleRoot, ipfsCid);
        }
    }
    function setApprovedTraderByMerkleProof(bool direction, uint256 offerIndex, address trader, uint256 allocation, bytes32[] calldata proof) external override {
        require(offerMerkleRoot[direction][offerIndex] != 0, "merkle root not set");
        require(
            MerkleProof.verifyCalldata(proof, offerMerkleRoot[direction][offerIndex], keccak256(abi.encodePacked(msg.sender, allocation)))
        , "merkle proof failed");

        uint256 delta = allocation.sub(lastTraderAllocation[direction][offerIndex][trader], "new allocation smaller than original");
        lastTraderAllocation[direction][offerIndex][trader] = allocation;
        uint256 newAllocation = traderAllocation[direction][offerIndex][trader].add(delta);

        // collect fee from trader instead of LP
        uint256 fee = uint256(IOSWAP_ConfigStore(configStore).customParam(FEE_PER_TRADER));
        prepaidFeeBalance[direction][offerIndex] = prepaidFeeBalance[direction][offerIndex].sub(fee);
        feeBalance = feeBalance.add(fee);

        _setApprovedTrader(direction, offerIndex, trader, newAllocation);
    }

}