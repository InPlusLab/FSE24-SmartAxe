// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IOSWAP_VotingExecutorManager {
    function govToken() external view returns (IERC20 govToken);
    function votingExecutor(uint256 index) external view returns (address);
    function votingExecutorInv(address) external view returns (uint256 votingExecutorInv);
    function isVotingExecutor(address) external view returns (bool isVotingExecutor);
    function trollRegistry() external view returns (address trollRegistry);
    function newVotingExecutorManager() external view returns (IOSWAP_VotingExecutorManager newVotingExecutorManager);

    function votingExecutorLength() external view returns (uint256);
    function setVotingExecutor(address _votingExecutor, bool _bool) external;
}