// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IWOKT.sol";
import './StakingRewards.sol';


contract StakingRewardsFactory is Ownable {

    address public wokt;
    mapping(address => address payable) public stakingRewardsAddressByStakingToken;

    event Deploy(address stakingToken, address stakingRewards);

    constructor(
        address _wokt
    ) public {
        wokt = _wokt;
    }

    // deploy a staking reward contract for the staking token, and store the reward amount
    // the reward will be distributed to the staking reward contract no sooner than the genesis
    function deploy(address stakingToken) public onlyOwner {
        address stakingRewards = stakingRewardsAddressByStakingToken[stakingToken];
        require(stakingRewards == address(0), 'StakingRewardsFactory::deploy: already deployed');
        address payable newStakingRewards = address(new StakingRewards(stakingToken, wokt));
        stakingRewardsAddressByStakingToken[stakingToken] = newStakingRewards;

        emit Deploy(stakingToken, newStakingRewards);
    }

    // notify reward amount for an individual staking token.
    // this is a fallback in case the notifyRewardAmounts costs too much gas to call for all contracts
    function notifyRewardAmount(address stakingToken, uint256 rewardsDuration, uint256 rewardAmount) public onlyOwner{

        address payable stakingRewards = stakingRewardsAddressByStakingToken[stakingToken];
        require(stakingRewards != address(0), 'StakingRewardsFactory::notifyRewardAmount: not deployed');

        if (rewardAmount > 0) {
            require(address(this).balance >= rewardAmount, "StakingRewardsFactory::notifyRewardAmount: insufficient rewards");
            IWOKT rewardsToken = IWOKT(wokt);
            rewardsToken.deposit{value: rewardAmount}();
            require(
                rewardsToken.transfer(stakingRewards, rewardAmount),
                'StakingRewardsFactory::notifyRewardAmount: transfer failed'
            );
            StakingRewards(stakingRewards).notifyRewardAmount(rewardAmount,rewardsDuration);
        }
    }

    receive() external payable {}
}