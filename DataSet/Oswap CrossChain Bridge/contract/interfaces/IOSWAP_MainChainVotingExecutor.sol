// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >= 0.8.6;

import './IOSWAP_ChainRegistry.sol';
import './IOSWAP_ConfigStore.sol';
import './IOSWAP_MainChainTrollRegistry.sol';
import './IOSWAP_VotingManager.sol';

interface IOSWAP_MainChainVotingExecutor  {
    event Execute(bytes32[] params);

    function trollRegistry() external view returns (IOSWAP_MainChainTrollRegistry trollRegistry);
    function votingManager() external view returns (IOSWAP_VotingManager votingManager);
    function chainRegistry() external view returns (IOSWAP_ChainRegistry chainRegistry);
    function initAddress(IOSWAP_ChainRegistry _chainRegistry) external;
    function execute(bytes32[] calldata params) external;
}