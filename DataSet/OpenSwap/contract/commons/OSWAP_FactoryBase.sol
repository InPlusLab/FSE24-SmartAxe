// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './interfaces/IOSWAP_FactoryBase.sol';
import '../gov/interfaces/IOAXDEX_Governance.sol';
import './interfaces/IOSWAP_PairBase.sol';
import './OSWAP_PausableFactory.sol';

contract OSWAP_FactoryBase is IOSWAP_FactoryBase, OSWAP_PausableFactory {
    modifier onlyVoting() {
        require(IOAXDEX_Governance(governance).isVotingExecutor(msg.sender), "Not from voting");
        _; 
    }

    address public override pairCreator;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    constructor(address _governance, address _pairCreator) OSWAP_PausableFactory(_governance) public {
        pairCreator = _pairCreator;
    }

    function allPairsLength() external override view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'PAIR_EXISTS'); // single check is sufficient

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        // bytes4(keccak256(bytes('createPair(bytes32)')));
        (bool success, bytes memory data) = pairCreator.delegatecall(abi.encodeWithSelector(0xED25A5A2, salt));
        require(success, "Failed to create pair");
        (pair) = abi.decode(data, (address));
        IOSWAP_PairBase(pair).initialize(token0, token1);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}