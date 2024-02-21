// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import './OSWAP_MainChainTrollRegistry.sol';
import './OSWAP_MainChainVotingExecutor.sol';
import './OSWAP_VotingManager.sol';
import './OSWAP_VotingRegistry.sol';

contract OSWAP_VotingContract {

    uint256 constant WEI = 10 ** 18;

    OSWAP_MainChainTrollRegistry public immutable trollRegistry;
    OSWAP_VotingManager public immutable votingManager;
    OSWAP_MainChainVotingExecutor public immutable executor;

    uint256 public immutable id;
    bytes32 public immutable name;
    bytes32[] public options;
    uint256 public immutable quorum;
    uint256 public immutable threshold;

    uint256 public immutable voteStartTime;
    uint256 public immutable voteEndTime;
    uint256 public immutable executeDelay;
    bool public executed;
    bool public vetoed;


    mapping (address => uint256) public accountVoteOption;
    mapping (address => uint256) public accountVoteWeight;
    uint256[] public  optionsWeight;
    uint256 public totalVoteWeight;
    uint256 public totalWeight;
    bytes32[] public executeParam;


    struct Params {
        OSWAP_MainChainVotingExecutor executor; 
        uint256 id; 
        bytes32 name; 
        bytes32[] options; 
        uint256 quorum; 
        uint256 threshold; 
        uint256 voteEndTime;
        uint256 executeDelay; 
        bytes32[] executeParam;
    }
    constructor(
        Params memory params
    ) {
        OSWAP_MainChainTrollRegistry _trollRegistry = OSWAP_VotingRegistry(msg.sender).trollRegistry();
        OSWAP_VotingManager _votingManager = OSWAP_VotingRegistry(msg.sender).votingManager();
        votingManager = _votingManager;
        trollRegistry = _trollRegistry;
        require(block.timestamp <= params.voteEndTime, 'VotingContract: Voting already ended');
        if (params.executeParam.length != 0) {
            require(_votingManager.isVotingExecutor(address(params.executor)), "VotingContract: Invalid executor");
            require(params.options.length == 2 && params.options[0] == 'Y' && params.options[1] == 'N', "VotingContract: Invalid options");
            require(params.threshold <= WEI, "VotingContract: Invalid threshold");
            require(params.executeDelay > 0, "VotingContract: Invalid execute delay");
        }

        executor = params.executor;
        totalWeight = _trollRegistry.totalStake();
        id = params.id;
        name = params.name;
        options = params.options;
        quorum = params.quorum;
        threshold = params.threshold;
        optionsWeight = new uint256[](params.options.length);

        voteStartTime = block.timestamp;
        voteEndTime = params.voteEndTime;
        executeDelay = params.executeDelay;
        executeParam = params.executeParam;
    }
    function getParams() external view returns (
        address executor_,
        uint256 id_,
        bytes32 name_,
        bytes32[] memory options_,
        uint256 voteStartTime_,
        uint256 voteEndTime_,
        uint256 executeDelay_,
        bool[2] memory status_, // [executed, vetoed]
        uint256[] memory optionsWeight_,
        uint256[3] memory quorum_, // [quorum, threshold, totalWeight]
        bytes32[] memory executeParam_
    ) {
        return (address(executor), id, name, options, voteStartTime, voteEndTime, executeDelay, [executed, vetoed], optionsWeight, [quorum, threshold, totalWeight], executeParam);
    }
    function veto() external {
        require(msg.sender == address(votingManager), 'OSWAP_VotingContract: Not from Governance');
        require(!executed, 'OSWAP_VotingContract: Already executed');
        vetoed = true;
    }
    function optionsLength() external view returns(uint256){
        return options.length;
    }
    function allOptions() external view returns (bytes32[] memory){
        return options;
    }
    function allOptionsWeight() external view returns (uint256[] memory){
        return optionsWeight;
    }
    function execute() external {
        require(block.timestamp > voteEndTime + executeDelay, "VotingContract: Execute delay not past yet");
        require(!vetoed, 'VotingContract: Vote already vetoed');
        require(!executed, 'VotingContract: Vote already executed');
        require(executeParam.length != 0, 'VotingContract: Execute param not defined');

        require(totalVoteWeight >= quorum, 'VotingContract: Quorum not met');
        require(optionsWeight[0] > optionsWeight[1], "VotingContract: Majority not met"); // 0: Y, 1:N
        require(optionsWeight[0] * WEI > totalVoteWeight * threshold, "VotingContract: Threshold not met");
        executed = true;
        executor.execute(executeParam);
        votingManager.executed();
    }
    function vote(uint256 option) external {
        require(block.timestamp <= voteEndTime, 'VotingContract: Vote already ended');
        require(!vetoed, 'VotingContract: Vote already vetoed');
        require(!executed, 'VotingContract: Vote already executed');
        require(option < options.length, 'VotingContract: Invalid option');

        votingManager.voted(executeParam.length == 0, msg.sender, option);

        uint256 currVoteWeight = accountVoteWeight[msg.sender];
        if (currVoteWeight > 0){
            uint256 currVoteIdx = accountVoteOption[msg.sender];
            optionsWeight[currVoteIdx] = optionsWeight[currVoteIdx] - currVoteWeight;
            totalVoteWeight = totalVoteWeight - currVoteWeight;
        }

        uint256 weight = trollRegistry.stakeOf(msg.sender);
        require(weight > 0, "VotingContract: Not staked to vote");
        accountVoteOption[msg.sender] = option;
        accountVoteWeight[msg.sender] = weight;
        optionsWeight[option] = optionsWeight[option] + weight;
        totalVoteWeight = totalVoteWeight + weight;

        totalWeight = trollRegistry.totalStake();
    }
    function updateWeight(address account) external {
        // use if-cause and don't use requrie() here to avoid revert as Governance is looping through all votings
        if (block.timestamp <= voteEndTime && !vetoed && !executed){
            uint256 weight = trollRegistry.stakeOf(account);
            uint256 currVoteWeight = accountVoteWeight[account];
            if (currVoteWeight > 0 && currVoteWeight != weight){
                uint256 currVoteIdx = accountVoteOption[account];
                accountVoteWeight[account] = weight;
                optionsWeight[currVoteIdx] = optionsWeight[currVoteIdx] - currVoteWeight + weight;
                totalVoteWeight = totalVoteWeight - currVoteWeight + weight;
            }
            totalWeight = trollRegistry.totalStake();
        }
    }
    function executeParamLength() external view returns (uint256){
        return executeParam.length;
    }
    function allExecuteParam() external view returns (bytes32[] memory){
        return executeParam;
    }
}