// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import '../interfaces/IOKCSwapFactory.sol';
import './OKCSwapPair.sol';

contract OKCSwapFactory is IOKCSwapFactory {
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'OKCSwap: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'OKCSwap: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'OKCSwap: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(OKCSwapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IOKCSwapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'OKCSwap: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'OKCSwap: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function getHash() public pure returns(bytes32){
        return keccak256(type(OKCSwapPair).creationCode);
    }

}
