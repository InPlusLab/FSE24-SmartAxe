// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IAuthorization.sol";
import "./IOSWAP_VotingExecutorManager.sol";
import "./IOSWAP_SwapPolicy.sol";

interface IOSWAP_ConfigStore is IAuthorization {

    event ParamSet1(bytes32 indexed name, bytes32 value1);
    event ParamSet2(bytes32 indexed name, bytes32 value1, bytes32 value2);
    event UpdateVotingExecutorManager(IOSWAP_VotingExecutorManager newVotingExecutorManager);
    event Upgrade(IOSWAP_ConfigStore newConfigStore);

    function govToken() external view returns (IERC20 govToken);
    function votingExecutorManager() external view returns (IOSWAP_VotingExecutorManager votingExecutorManager);
    function swapPolicy() external view returns (IOSWAP_SwapPolicy swapPolicy);

    function priceOracle(IERC20 token) external view returns (address priceOracle); // priceOracle[token] = oracle
    function baseFee(IERC20 asset) external view returns (uint256 baseFee);
    function isApprovedProxy(address proxy) external view returns (bool isApprovedProxy);
    function lpWithdrawlDelay() external view returns (uint256 lpWithdrawlDelay);
    function transactionsGap() external view returns (uint256 transactionsGap); // side chain
    function superTrollMinCount() external view returns (uint256 superTrollMinCount); // side chain
    function generalTrollMinCount() external view returns (uint256 generalTrollMinCount); // side chain
    function transactionFee() external view returns (uint256 transactionFee);
    function router() external view returns (address router);
    function rebalancer() external view returns (address rebalancer);
    function newConfigStore() external view returns (IOSWAP_ConfigStore newConfigStore);
    function feeTo() external view returns (address feeTo);
    struct Params {
        IOSWAP_VotingExecutorManager votingExecutorManager;
        IOSWAP_SwapPolicy swapPolicy;
        uint256 lpWithdrawlDelay;
        uint256 transactionsGap;
        uint256 superTrollMinCount;
        uint256 generalTrollMinCount;
        uint256 minStakePeriod;
        uint256 transactionFee;
        address router;
        address rebalancer;
        address wrapper;
        IERC20[] asset;
        uint256[] baseFee;
    }

    function initAddress(IOSWAP_VotingExecutorManager _votingExecutorManager) external;
    function upgrade(IOSWAP_ConfigStore _configStore) external;
    function updateVotingExecutorManager() external;
    function setMinStakePeriod(uint256 _minStakePeriod) external;
    function setConfigAddress(bytes32 name, bytes32 _value) external;
    function setConfig(bytes32 name, bytes32 _value) external;
    function setConfig2(bytes32 name, bytes32 value1, bytes32 value2) external;
    function setOracle(IERC20 asset, address oracle) external;
    function setSwapPolicy(IOSWAP_SwapPolicy _swapPolicy) external;
    function getSignatureVerificationParams() external view returns (uint256,uint256,uint256);
    function getBridgeParams(IERC20 asset) external view returns (IOSWAP_SwapPolicy,address,address,address,uint256,uint256);
    function getRebalanceParams(IERC20 asset) external view returns (address rebalancer, address govTokenOracle, address assetTokenOracle);
}