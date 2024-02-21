// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

interface IOAXDEX_VotingRegistry {
    function governance() external view returns (address);
    function newVote(address executor,
                        bytes32 name, 
                        bytes32[] calldata options, 
                        uint256 quorum, 
                        uint256 threshold, 
                        uint256 voteEndTime,
                        uint256 executeDelay, 
                        bytes32[] calldata executeParam
    ) external;
}