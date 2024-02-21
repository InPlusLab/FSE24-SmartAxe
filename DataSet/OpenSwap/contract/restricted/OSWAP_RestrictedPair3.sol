// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './interfaces/IOSWAP_RestrictedPair3.sol';
import './interfaces/IOSWAP_ConfigStore.sol';
import './OSWAP_RestrictedPairPrepaidFee.sol';

// traders set their own allocation from signature obtained from liquidity provider
contract OSWAP_RestrictedPair3 is IOSWAP_RestrictedPair3, OSWAP_RestrictedPairPrepaidFee {

    mapping(bool => mapping(uint256 => mapping(address => bool))) public override allocationSet;

    function _recoverSigner(bytes32 hash, bytes memory signature) private pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        if (signature.length != 65) {
            return (address(0));
        }
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        if (v < 27) {
            v += 27;
        }
        if (v != 27 && v != 28) {
            return (address(0));
        } else {
            hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
            return ecrecover(hash, v, r, s);
        }
    }
    function setApprovedTraderBySignature(bool direction, uint256 offerIndex, address trader, uint256 allocation, bytes calldata signature) external override {
        require(!allocationSet[direction][offerIndex][trader], "already set");
        allocationSet[direction][offerIndex][trader] = true;

        address signer = _recoverSigner(keccak256(abi.encodePacked(direction, offerIndex, trader, allocation)), signature);
        require(signer == offers[direction][offerIndex].provider, "invalid signature");

        // collect fee from trader instead of LP
        uint256 fee = uint256(IOSWAP_ConfigStore(configStore).customParam(FEE_PER_TRADER));
        prepaidFeeBalance[direction][offerIndex] = prepaidFeeBalance[direction][offerIndex].sub(fee);
        feeBalance = feeBalance.add(fee);

        _setApprovedTrader(direction, offerIndex, trader, allocation);
    }
}