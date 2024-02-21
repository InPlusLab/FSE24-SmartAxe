// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interface/IFeeNFT.sol";
import "../utils/Role.sol";


contract FeeNFT is IFeeNFT, Role {
    uint immutable chainId = block.chainid;
    // from chain、 to chain 、fee
    mapping(uint => mapping(uint => uint)) public chainNFTFee;
    //chain token
    mapping(uint => address) public chainNativeToken;

    function setChainNFTFee(uint fromChain, uint toChain, uint fee) external onlyManager {
        chainNFTFee[fromChain][toChain] = fee;
    }

    function setToChainNFTFee(uint toChain, uint fee) external onlyManager {
        chainNFTFee[chainId][toChain] = fee;
    }

    function getChainNFTFee(uint fromChain, uint toChain) external view override returns (uint){
        return chainNFTFee[fromChain][toChain];
    }

    function getToChainNFTFee(uint toChain) external view override returns (uint){
        return chainNFTFee[chainId][toChain];
    }

    function setChainNativeToken(uint chain, address token) external onlyManager {
        chainNativeToken[chain] = token;
    }

    function getChainNativeToken(uint chain) external view override returns (address){
        return chainNativeToken[chain];
    }

    function getChainNativeTokenAndFee(uint fromChain, uint toChain) external view override returns (address token, uint fee){
        token = chainNativeToken[fromChain];
        fee = chainNFTFee[fromChain][toChain];
    }
}