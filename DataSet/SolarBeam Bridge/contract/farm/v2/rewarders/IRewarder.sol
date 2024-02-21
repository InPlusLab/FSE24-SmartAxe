// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../libraries/IBoringERC20.sol";

interface IRewarder {
    function onSolarReward(address user, uint256 newLpAmount) external;

    function pendingTokens(address user)
        external
        view
        returns (uint256 pending);

    function rewardToken() external view returns (IBoringERC20);
}
