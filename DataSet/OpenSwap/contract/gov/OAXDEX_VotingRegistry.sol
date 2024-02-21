// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import "./interfaces/IOAXDEX_VotingRegistry.sol";
import "./OAXDEX_VotingContract.sol";
import '../libraries/SafeMath.sol';

contract OAXDEX_VotingRegistry is IOAXDEX_VotingRegistry {
    using SafeMath for uint256;

    address public override governance;

    constructor(address _governance) public {
        governance = _governance;
    }

    function newVote(address executor,
                     bytes32 name, 
                     bytes32[] calldata options, 
                     uint256 quorum, 
                     uint256 threshold, 
                     uint256 voteEndTime,
                     uint256 executeDelay, 
                     bytes32[] calldata executeParam
    ) external override {
        bool isExecutiveVote = executeParam.length != 0;
        {
        require(IOAXDEX_Governance(governance).isVotingExecutor(executor), "OAXDEX_VotingRegistry: Invalid executor");
        bytes32 configName = isExecutiveVote ? executeParam[0] : bytes32("poll");
        (uint256 minExeDelay, uint256 minVoteDuration, uint256 maxVoteDuration, uint256 minOaxTokenToCreateVote, uint256 minQuorum) = IOAXDEX_Governance(governance).getVotingParams(configName);
        uint256 staked = IOAXDEX_Governance(governance).stakeOf(msg.sender);
        require(staked >= minOaxTokenToCreateVote, "OAXDEX_VotingRegistry: minOaxTokenToCreateVote not met");
        require(voteEndTime.sub(block.timestamp) >= minVoteDuration, "OAXDEX_VotingRegistry: minVoteDuration not met");
        require(voteEndTime.sub(block.timestamp) <= maxVoteDuration, "OAXDEX_VotingRegistry: exceeded maxVoteDuration");
        if (isExecutiveVote) {
            require(quorum >= minQuorum, "OAXDEX_VotingRegistry: minQuorum not met");
            require(executeDelay >= minExeDelay, "OAXDEX_VotingRegistry: minExeDelay not met");
        }
        }

        uint256 id = IOAXDEX_Governance(governance).getNewVoteId();
        OAXDEX_VotingContract voting = new OAXDEX_VotingContract(governance, executor, id, name, options, quorum, threshold, voteEndTime, executeDelay, executeParam);
        IOAXDEX_Governance(governance).newVote(address(voting), isExecutiveVote);
    }
}