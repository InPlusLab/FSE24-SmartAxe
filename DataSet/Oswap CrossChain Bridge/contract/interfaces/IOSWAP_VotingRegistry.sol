// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "./IOSWAP_MainChainTrollRegistry.sol";
import './IOSWAP_MainChainVotingExecutor.sol';
import "./IOSWAP_VotingManager.sol";

interface OSWAP_VotingRegistry {
    function trollRegistry() external view returns (IOSWAP_MainChainTrollRegistry trollRegistry);
    function votingManager() external view returns (IOSWAP_VotingManager votingManager);

    function newVote(
        IOSWAP_MainChainVotingExecutor executor,
        bytes32 name, 
        bytes32[] calldata options, 
        uint256 quorum, 
        uint256 threshold, 
        uint256 voteEndTime,
        uint256 executeDelay, 
        bytes32[] calldata executeParam
    ) external;
}