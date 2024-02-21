// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import './IOSWAP_MainChainTrollRegistry.sol';
import './IOSWAP_MainChainVotingExecutor.sol';
import './IOSWAP_VotingManager.sol';

interface IOSWAP_VotingContract {

    function trollRegistry() external view returns (IOSWAP_MainChainTrollRegistry trollRegistry);
    function votingManager() external view returns (IOSWAP_VotingManager votingManager);
    function executor() external view returns (IOSWAP_MainChainVotingExecutor executor);
    function id() external view returns (uint256 id);
    function name() external view returns (bytes32 name);
    function options(uint256 index) external view returns (bytes32);
    function quorum() external view returns (uint256 quorum);
    function threshold() external view returns (uint256 threshold);
    function voteStartTime() external view returns (uint256 voteStartTime);
    function voteEndTime() external view returns (uint256 voteEndTime);
    function executeDelay() external view returns (uint256 executeDelay);
    function executed() external view returns (bool executed);
    function vetoed() external view returns (bool vetoed);
    function accountVoteOption(address) external view returns (uint256 accountVoteOption);
    function accountVoteWeight(address) external view returns (uint256 accountVoteWeight);
    function optionsWeight(uint256 index) external view returns (uint256);
    function totalVoteWeight() external view returns (uint256 totalVoteWeight);
    function totalWeight() external view returns (uint256 totalWeight);
    function executeParam(uint256 index) external view returns (bytes32);

    struct Params {
        IOSWAP_MainChainVotingExecutor executor; 
        uint256 id; 
        bytes32 name; 
        bytes32[] options; 
        uint256 quorum; 
        uint256 threshold; 
        uint256 voteEndTime;
        uint256 executeDelay; 
        bytes32[] executeParam;
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
    );
    function veto() external;
    function optionsLength() external view returns(uint256);
    function allOptions() external view returns (bytes32[] memory);
    function allOptionsWeight() external view returns (uint256[] memory);
    function execute() external;
    function vote(uint256 option) external;
    function updateWeight(address account) external;
    function executeParamLength() external view returns(uint256);
    function allExecuteParam() external view returns (bytes32[] memory);
}