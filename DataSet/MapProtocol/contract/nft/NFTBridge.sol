// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './NFTToken.sol';
import '../utils/Role.sol';
import '../interface/IFeeNFT.sol';


contract NFTBridge is Role {
    uint immutable chainId = block.chainid;
    uint nonce;
    IFeeNFT feeNFT;
    mapping(address => mapping(uint => address)) public wrappedAssets;


    event mapTransferInNFT(bytes32 indexed orderId,address indexed token, uint tokenID, uint fromChain, uint toChain, uint nativeChain);
    event mapTransferOutNFT(bytes32  indexed orderId,address  indexed token, uint tokenID, uint fromChain, uint toChain, uint nativeChain);

    function setFeeNFT(address feeNft) external onlyManager{
        feeNFT = IFeeNFT(feeNft);
    }

    function getNFTTransferFee(uint toChain) public view returns(uint){
        return feeNFT.getToChainNFTFee(toChain);
    }

    function getOrderID(address token, address from, address to, uint toChainID) public returns (bytes32){
        return keccak256(abi.encodePacked(nonce++, from, to, token, chainId, toChainID));
    }

    function transferOutNFT(address _token, address to, uint tokenID, uint toChain) public payable {
        require(msg.value >= getNFTTransferFee(toChain),"transfer fee too low");

        NFTToken token = NFTToken(_token);

        bytes32 orderId = getOrderID(_token,msg.sender,to,toChain);

        if (token.nativeContract() != address(0)) {
            token.lock(msg.sender, tokenID);
            emit mapTransferOutNFT(orderId,token.nativeContract(), tokenID, chainId, toChain, token.nativeChain());
        } else {
            IERC721(token).transferFrom(msg.sender, address(this), tokenID);
            emit mapTransferOutNFT(orderId,_token, tokenID, chainId, toChain, token.nativeChain());
        }
    }

    function transferInNFT(address _token, address to, uint tokenID, uint fromChain, uint toChain, uint nativeChain,
        string memory name, string memory symbol, string memory tokenURI) public onlyManager {
        NFTToken token = NFTToken(_token);

        bytes32 orderId = getOrderID(_token,msg.sender,to,chainId);

        if (chainId == nativeChain) {
            IERC721(token).transferFrom(address(this), to, tokenID);
            emit mapTransferInNFT(orderId,_token, tokenID, fromChain, chainId, nativeChain);
        } else {
            address localWrapped = wrappedAssets[_token][fromChain];
            if (localWrapped == address(0)) {
                token = new NFTToken(name, symbol, _token, fromChain);
                wrappedAssets[_token][fromChain] = address(token);
            } else {
                token = NFTToken(localWrapped);
            }
            token.mint(to, tokenID);
            token.setTokenURI(tokenID, tokenURI);
            emit mapTransferInNFT(orderId,_token, tokenID, fromChain, chainId, token.nativeChain());
        }
    }
}