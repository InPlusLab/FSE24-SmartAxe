// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import "../../commons/interfaces/IOSWAP_PausableFactory.sol";

interface IOSWAP_RestrictedFactory is IOSWAP_PausableFactory { 

    event PairCreated(address indexed token0, address indexed token1, address pair, uint newPairSize, uint newSize);
    event Shutdowned();
    event Restarted();
    event PairShutdowned(address indexed pair);
    event PairRestarted(address indexed pair);
    event ParamSet(bytes32 name, bytes32 value);
    event ParamSet2(bytes32 name, bytes32 value1, bytes32 value2);
    event OracleAdded(address indexed token0, address indexed token1, address oracle);

    function whitelistFactory() external view returns (address);
    function pairCreator() external returns (address);
    function configStore() external returns (address);

    function tradeFee() external returns (uint256);
    function protocolFee() external returns (uint256);
    function protocolFeeTo() external returns (address);

    function getPair(address tokenA, address tokenB, uint256 i) external returns (address pair);
    function pairIdx(address pair) external returns (uint256 i);
    function allPairs(uint256 i) external returns (address pair);

    function restrictedLiquidityProvider() external returns (address);
    function oracles(address tokenA, address tokenB) external returns (address oracle);
    function isOracle(address oracle) external returns (bool);

    function init(address _restrictedLiquidityProvider) external;
    function getCreateAddresses() external view returns (address _governance, address _whitelistFactory, address _restrictedLiquidityProvider, address _configStore);

    function pairLength(address tokenA, address tokenB) external view returns (uint256);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setOracle(address tokenA, address tokenB, address oracle) external;
    function addOldOracleToNewPair(address tokenA, address tokenB, address oracle) external;

    function isPair(address pair) external view returns (bool);

    function setTradeFee(uint256 _tradeFee) external;
    function setProtocolFee(uint256 _protocolFee) external;
    function setProtocolFeeTo(address _protocolFeeTo) external;

    function checkAndGetOracleSwapParams(address tokenA, address tokenB) external view returns (address oracle_, uint256 tradeFee_, uint256 protocolFee_);
    function checkAndGetOracle(address tokenA, address tokenB) external view returns (address oracle);
}