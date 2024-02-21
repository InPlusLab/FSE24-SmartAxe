// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Authorization.sol";
import "./interfaces/IOSWAP_SwapPolicy.sol";
import "./interfaces/IOSWAP_VotingExecutorManager.sol";

contract OSWAP_ConfigStore is Authorization {

    modifier onlyVoting() {
        require(votingExecutorManager.isVotingExecutor(msg.sender), "OSWAP: Not from voting");
        _;
    }

    event ParamSet1(bytes32 indexed name, bytes32 value1);
    event ParamSet2(bytes32 indexed name, bytes32 value1, bytes32 value2);
    event UpdateVotingExecutorManager(IOSWAP_VotingExecutorManager newVotingExecutorManager);
    event Upgrade(OSWAP_ConfigStore newConfigStore);

    IERC20 public immutable govToken;
    IOSWAP_VotingExecutorManager public votingExecutorManager;
    IOSWAP_SwapPolicy public swapPolicy;

    // side chain
    mapping(IERC20 => address) public priceOracle; // priceOracle[token] = oracle
    mapping(IERC20 => uint256) public baseFee;
    mapping(address => bool) public isApprovedProxy;
    uint256 public lpWithdrawlDelay;
    uint256 public transactionsGap;
    uint256 public superTrollMinCount;
    uint256 public generalTrollMinCount;
    uint256 public transactionFee;
    address public router;
    address public rebalancer;
    address public feeTo;

    OSWAP_ConfigStore public newConfigStore;

    struct Params {
        IERC20 govToken;
        IOSWAP_SwapPolicy swapPolicy;
        uint256 lpWithdrawlDelay;
        uint256 transactionsGap;
        uint256 superTrollMinCount;
        uint256 generalTrollMinCount;
        uint256 transactionFee;
        address router;
        address rebalancer;
        address feeTo;
        address wrapper;
        IERC20[] asset;
        uint256[] baseFee;
    }
    constructor(
        Params memory params
    ) {
        govToken = params.govToken;
        swapPolicy = params.swapPolicy;
        lpWithdrawlDelay = params.lpWithdrawlDelay;
        transactionsGap = params.transactionsGap;
        superTrollMinCount = params.superTrollMinCount;
        generalTrollMinCount = params.generalTrollMinCount;
        transactionFee = params.transactionFee;
        router = params.router;
        rebalancer = params.rebalancer;
        feeTo = params.feeTo;
        require(params.asset.length == params.baseFee.length);
        for (uint256 i ; i < params.asset.length ; i++){
            baseFee[params.asset[i]] = params.baseFee[i];
        }
        if (params.wrapper != address(0))
            isApprovedProxy[params.wrapper] = true;
        isPermitted[msg.sender] = true;
    }
    function initAddress(IOSWAP_VotingExecutorManager _votingExecutorManager) external onlyOwner {
        require(address(_votingExecutorManager) != address(0), "null address");
        require(address(votingExecutorManager) == address(0), "already init");
        votingExecutorManager = _votingExecutorManager;
    }

    function upgrade(OSWAP_ConfigStore _configStore) external onlyVoting {
        // require(address(_configStore) != address(0), "already set");
        newConfigStore = _configStore;
        emit Upgrade(newConfigStore);
    }
    function updateVotingExecutorManager() external {
        IOSWAP_VotingExecutorManager _votingExecutorManager = votingExecutorManager.newVotingExecutorManager();
        require(address(_votingExecutorManager) != address(0), "Invalid config store");
        votingExecutorManager = _votingExecutorManager;
        emit UpdateVotingExecutorManager(votingExecutorManager);
    }

    // side chain
    function setConfigAddress(bytes32 name, bytes32 _value) external onlyVoting {
        address value = address(bytes20(_value));

        if (name == "router") {
            router = value;
        } else if (name == "rebalancer") {
            rebalancer = value;
        } else if (name == "feeTo") {
            feeTo = value;
        } else {
            revert("Invalid config");
        }
        emit ParamSet1(name, _value);
    }
    function setConfig(bytes32 name, bytes32 _value) external onlyVoting {
        uint256 value = uint256(_value);
        if (name == "transactionsGap") {
            transactionsGap = value;
        } else if (name == "transactionFee") {
            transactionFee = value;
        } else if (name == "superTrollMinCount") {
            superTrollMinCount = value;
        } else if (name == "generalTrollMinCount") {
            generalTrollMinCount = value;
        } else if (name == "lpWithdrawlDelay") {
            lpWithdrawlDelay = value;
        } else {
            revert("Invalid config");
        }
        emit ParamSet1(name, _value);
    }
    function setConfig2(bytes32 name, bytes32 value1, bytes32 value2) external onlyVoting {
        if (name == "baseFee") {
            baseFee[IERC20(address(bytes20(value1)))] = uint256(value2);
        } else if (name == "isApprovedProxy") {
            isApprovedProxy[address(bytes20(value1))] = uint256(value2)==1;
        } else {
            revert("Invalid config");
        }
        emit ParamSet2(name, value1, value2);
    }
    function setOracle(IERC20 asset, address oracle) external auth {
        priceOracle[asset] = oracle;
        emit ParamSet2("oracle", bytes20(address(asset)), bytes20(oracle));
    }
    function setSwapPolicy(IOSWAP_SwapPolicy _swapPolicy) external auth {
        swapPolicy = _swapPolicy;
        emit ParamSet1("swapPolicy", bytes32(bytes20(address(_swapPolicy))));
    }
    function getSignatureVerificationParams() external view returns (uint256,uint256,uint256) {
        return (generalTrollMinCount, superTrollMinCount, transactionsGap);
    }
    function getBridgeParams(IERC20 asset) external view returns (IOSWAP_SwapPolicy,address,address,address,uint256,uint256) {
        return (swapPolicy, router, priceOracle[govToken], priceOracle[asset], baseFee[asset], transactionFee);
    }
    function getRebalanceParams(IERC20 asset) external view returns (address,address,address) {
        return (rebalancer, priceOracle[govToken], priceOracle[asset]);
    }
}