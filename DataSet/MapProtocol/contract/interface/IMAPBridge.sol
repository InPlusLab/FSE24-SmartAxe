// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMAPBridge {
    function transferOutTokenBurn(address token, address to, uint amount, uint toChainId) external ;
    function transferOutToken(address token, address to, uint amount, uint toChainId) external ;
    function transferOutNative(address to, uint amount, uint toChainId) external payable ;
    function transferInToken(address token, address from, address payable to, uint amount, bytes32 orderId, uint fromChain, uint toChain) external;
    function transferInTokenMint(address token, address from, address payable to, uint amount, bytes32 orderId, uint fromChain, uint toChain) external;
    function transferInNative(address from, address payable to, uint amount, bytes32 orderId, uint fromChain, uint toChain) external;
    function chainGasFee(uint chain) external view returns(uint);

    event mapTransferOut(address indexed token, address indexed from, address indexed to, bytes32 orderId, uint amount, uint fromChain, uint toChain);
    event mapTransferIn(address indexed token, address indexed from, address indexed to, bytes32 orderId, uint amount, uint fromChain, uint toChain);
    event mapTokenRegister(bytes32 tokenID, address token);
}