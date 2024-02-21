// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import "./IRewarder.sol";
import "../libraries/BoringERC20.sol";

contract RewarderBroken is IRewarder {
    IBoringERC20 public override rewardToken;

    function onSolarReward(address, uint256) external pure override {
        revert();
    }

    function pendingTokens(address) external pure override returns (uint256) {
        revert();
    }
}
