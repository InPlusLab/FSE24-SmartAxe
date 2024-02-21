// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "./IOSWAP_ChainRegistry.sol";
import "./IOSWAP_VotingManager.sol";

interface IOSWAP_ChainRegistryExecutor {
    function votingManager() external view returns (IOSWAP_VotingManager votingManager);
    function chainRegistry() external view returns (IOSWAP_ChainRegistry chainRegistry);

    event Execute(bytes32[] params);

    function execute(bytes32[] calldata params) external;
}