// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "./OSWAP_MainChainTrollRegistry.sol";
import './OSWAP_MainChainVotingExecutor.sol';
import "./OSWAP_VotingContract.sol";
import "./OSWAP_VotingManager.sol";

contract OSWAP_VotingRegistry {

    OSWAP_MainChainTrollRegistry public immutable trollRegistry;
    OSWAP_VotingManager public immutable votingManager;

    constructor(OSWAP_VotingManager _votingManager) {
        trollRegistry = _votingManager.trollRegistry();
        votingManager = _votingManager;
    }

    function newVote(
        OSWAP_MainChainVotingExecutor executor,
        bytes32 name, 
        bytes32[] calldata options, 
        uint256 quorum, 
        uint256 threshold, 
        uint256 voteEndTime,
        uint256 executeDelay, 
        bytes32[] calldata executeParam
    ) external {
        bool isExecutiveVote = executeParam.length != 0;
        {
        require(votingManager.isVotingExecutor(address(executor)), "OSWAP_VotingRegistry: Invalid executor");
        bytes32 configName = isExecutiveVote ? executeParam[0] : bytes32("poll");
        (uint256 minExeDelay, uint256 minVoteDuration, uint256 maxVoteDuration, uint256 minGovTokenToCreateVote, uint256 minQuorum) = votingManager.getVotingParams(configName);
        uint256 staked = trollRegistry.stakeOf(msg.sender);
        require(staked >= minGovTokenToCreateVote, "OSWAP_VotingRegistry: minGovTokenToCreateVote not met");
        require(voteEndTime >= minVoteDuration + block.timestamp, "OSWAP_VotingRegistry: minVoteDuration not met");
        require(voteEndTime <= maxVoteDuration + block.timestamp, "OSWAP_VotingRegistry: exceeded maxVoteDuration");
        if (isExecutiveVote) {
            require(quorum >= minQuorum, "OSWAP_VotingRegistry: minQuorum not met");
            require(executeDelay >= minExeDelay, "OSWAP_VotingRegistry: minExeDelay not met");
        }
        }

        uint256 id = votingManager.getNewVoteId();
        OSWAP_VotingContract voting = new OSWAP_VotingContract(
        OSWAP_VotingContract.Params({
            executor:executor, 
            id:id, 
            name:name, 
            options:options, 
            quorum:quorum, 
            threshold:threshold, 
            voteEndTime:voteEndTime, 
            executeDelay:executeDelay, 
            executeParam:executeParam
        }));
        votingManager.newVote(address(voting), isExecutiveVote);
    }
}