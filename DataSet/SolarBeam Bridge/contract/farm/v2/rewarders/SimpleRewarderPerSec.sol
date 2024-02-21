// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IRewarder.sol";
import "../ISolarDistributorV2.sol";
import "../libraries/BoringERC20.sol";

/**
 * This is a sample contract to be used in the SolarDistributorV2 contract for partners to reward
 * stakers with their native token alongside SOLAR.
 *
 * It assumes no minting rights, so requires a set amount of YOUR_TOKEN to be transferred to this contract prior.
 * E.g. say you've allocated 100,000 XYZ to the SOLAR-XYZ farm over 30 days. Then you would need to transfer
 * 100,000 XYZ and set the block reward accordingly so it's fully distributed after 30 days.
 */
contract SimpleRewarderPerSec is IRewarder, Ownable, ReentrancyGuard {
    using BoringERC20 for IBoringERC20;

    IBoringERC20 public immutable override rewardToken;
    uint256 public immutable pid;
    bool public immutable isNative;
    ISolarDistributorV2 public immutable distributorV2;

    /// @notice Info of each distributorV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of YOUR_TOKEN entitled to the user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    /// @notice Info of each distributorV2 poolInfo.
    /// `accTokenPerShare` Amount of YOUR_TOKEN each LP token is worth.
    /// `lastRewardTimestamp` The last timestamp YOUR_TOKEN was rewarded to the poolInfo.
    struct PoolInfo {
        uint256 accTokenPerShare;
        uint256 lastRewardTimestamp;
    }

    /// @notice Info of the poolInfo.
    PoolInfo public poolInfo;
    /// @notice Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    uint256 public tokenPerSec;
    uint256 private constant ACC_TOKEN_PRECISION = 1e12;

    event OnReward(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);

    modifier onlyDistributorV2() {
        require(
            msg.sender == address(distributorV2),
            "onlyDistributorV2: only SolarDistributorV2 can call this function"
        );
        _;
    }

    constructor(
        IBoringERC20 _rewardToken,
        uint256 _tokenPerSec,
        ISolarDistributorV2 _distributorV2,
        uint256 _pid,
        bool _isNative
    ) {
        require(
            Address.isContract(address(_rewardToken)),
            "constructor: reward token must be a valid contract"
        );
        require(
            Address.isContract(address(_distributorV2)),
            "constructor: SolarDistributorV2 must be a valid contract"
        );
        rewardToken = _rewardToken;
        pid = _pid;
        tokenPerSec = _tokenPerSec;
        distributorV2 = _distributorV2;
        isNative = _isNative;
        poolInfo = PoolInfo({
            lastRewardTimestamp: block.timestamp,
            accTokenPerShare: 0
        });
    }

    /// @notice Update reward variables of the given poolInfo.
    /// @return pool Returns the pool that was updated.
    function updatePool() public returns (PoolInfo memory pool) {
        pool = poolInfo;

        if (block.timestamp > pool.lastRewardTimestamp) {
            uint256 lpSupply = distributorV2.poolTotalLp(pid);

            if (lpSupply > 0) {
                uint256 timeElapsed = block.timestamp -
                    pool.lastRewardTimestamp;
                uint256 tokenReward = timeElapsed * tokenPerSec;
                pool.accTokenPerShare += ((tokenReward * ACC_TOKEN_PRECISION) /
                    lpSupply);
            }

            pool.lastRewardTimestamp = block.timestamp;
            poolInfo = pool;
        }
    }

    /// @notice Sets the distribution reward rate. This will also update the poolInfo.
    /// @param _tokenPerSec The number of tokens to distribute per second
    function setRewardRate(uint256 _tokenPerSec) external onlyOwner {
        updatePool();

        emit RewardRateUpdated(tokenPerSec, _tokenPerSec);

        tokenPerSec = _tokenPerSec;
    }

    /// @notice internal function to see balance of reward token.
    function _balance() internal view returns (uint256) {
        if (isNative) {
            return address(this).balance;
        } else {
            return rewardToken.balanceOf(address(this));
        }
    }

    /// @notice Function called by SolarDistributorV2 whenever staker claims SOLAR harvest. Allows staker to also receive a 2nd reward token.
    /// @param _user Address of user
    /// @param _lpAmount Number of LP tokens the user has
    function onSolarReward(address _user, uint256 _lpAmount)
        external
        override
        onlyDistributorV2
        nonReentrant
    {
        updatePool();
        PoolInfo memory pool = poolInfo;
        UserInfo storage user = userInfo[_user];
        uint256 pending;
        uint256 rewardBalance = _balance();
        if (user.amount > 0) {
            pending = (((user.amount * pool.accTokenPerShare) /
                ACC_TOKEN_PRECISION) - user.rewardDebt);

            if (isNative) {
                if (pending > rewardBalance) {
                    (bool success, ) = _user.call{value: rewardBalance}("");
                    require(success, "Transfer failed");
                } else {
                    (bool success, ) = _user.call{value: pending}("");
                    require(success, "Transfer failed");
                }
            } else {
                if (pending > rewardBalance) {
                    rewardToken.safeTransfer(_user, rewardBalance);
                } else {
                    rewardToken.safeTransfer(_user, pending);
                }
            }
        }
        user.amount = _lpAmount;
        user.rewardDebt =
            (user.amount * pool.accTokenPerShare) /
            ACC_TOKEN_PRECISION;

        emit OnReward(_user, pending);
    }

    /// @notice View function to see pending tokens
    /// @param _user Address of user.
    /// @return pending reward for a given user.
    function pendingTokens(address _user)
        external
        view
        override
        returns (uint256 pending)
    {
        PoolInfo memory pool = poolInfo;
        UserInfo storage user = userInfo[_user];

        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = distributorV2.poolTotalLp(pid);

        if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
            uint256 timeElapsed = block.timestamp - pool.lastRewardTimestamp;
            uint256 tokenReward = timeElapsed * tokenPerSec;
            accTokenPerShare += (tokenReward * ACC_TOKEN_PRECISION) / lpSupply;
        }

        pending = (((user.amount * accTokenPerShare) / ACC_TOKEN_PRECISION) -
            user.rewardDebt);
    }

    /// @notice In case rewarder is stopped before emissions finished, this function allows
    /// withdrawal of remaining tokens.
    function emergencyWithdraw() public onlyOwner {
        if (isNative) {
            (bool success, ) = msg.sender.call{value: address(this).balance}(
                ""
            );
            require(success, "Transfer failed");
        } else {
            rewardToken.safeTransfer(
                address(msg.sender),
                rewardToken.balanceOf(address(this))
            );
        }
    }

    /// @notice View function to see balance of reward token.
    function balance() external view returns (uint256) {
        return _balance();
    }

    /// @notice payable function needed to receive MOVR
    receive() external payable {}
}
