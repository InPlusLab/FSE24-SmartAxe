// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import './IOSWAP_ConfigStore.sol';
import "./IOSWAP_SideChainTrollRegistry.sol";

interface IOSWAP_SideChainVotingExecutor {
    event Execute(bytes32[] params);

    // from VotingManager
    function govToken() external view returns (IERC20 govToken);
    function trollRegistry() external view returns (IOSWAP_SideChainTrollRegistry trollRegistry);
    function configStore() external view returns (IOSWAP_ConfigStore configStore);

    function executeHash(bytes32[] calldata params, uint256 nonce) external view returns (bytes32);
    function execute(bytes[] calldata signatures, bytes32[] calldata params, uint256 nonce) external;
}