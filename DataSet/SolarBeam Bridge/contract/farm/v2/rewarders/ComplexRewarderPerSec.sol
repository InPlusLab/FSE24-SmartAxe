// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IComplexRewarder.sol";
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
contract ComplexRewarderPerSec is IComplexRewarder, Ownable, ReentrancyGuard {
    using BoringERC20 for IBoringERC20;

    IBoringERC20 public immutable override rewardToken;
    ISolarDistributorV2 public immutable distributorV2;
    bool public immutable isNative;

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
    /// `allocPoint` The amount of allocation points assigned to the pool.
    struct PoolInfo {
        uint256 accTokenPerShare;
        uint256 lastRewardTimestamp;
        uint256 allocPoint;
    }

    /// @notice Info of each pool.
    mapping(uint256 => PoolInfo) public poolInfo;

    uint256[] public poolIds;

    /// @notice Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    uint256 public tokenPerSec;
    uint256 private constant ACC_TOKEN_PRECISION = 1e12;

    event OnReward(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event AddPool(uint256 indexed pid, uint256 allocPoint);
    event SetPool(uint256 indexed pid, uint256 allocPoint);
    event UpdatePool(
        uint256 indexed pid,
        uint256 lastRewardTimestamp,
        uint256 lpSupply,
        uint256 accTokenPerShare
    );

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
        tokenPerSec = _tokenPerSec;
        distributorV2 = _distributorV2;
        isNative = _isNative;
    }

    /// @notice Add a new pool. Can only be called by the owner.
    /// @param _pid pool id on DistributorV2
    /// @param _allocPoint allocation of the new pool.
    function add(uint256 _pid, uint256 _allocPoint) public onlyOwner {
        require(poolInfo[_pid].lastRewardTimestamp == 0, "pool already exists");
        totalAllocPoint += _allocPoint;

        poolInfo[_pid] = PoolInfo({
            allocPoint: _allocPoint,
            lastRewardTimestamp: block.timestamp,
            accTokenPerShare: 0
        });
        poolIds.push(_pid);
        emit AddPool(_pid, _allocPoint);
    }

    /// @notice Update the given pool's allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    function set(uint256 _pid, uint256 _allocPoint) public onlyOwner {
        totalAllocPoint =
            totalAllocPoint -
            poolInfo[_pid].allocPoint +
            _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        emit SetPool(_pid, _allocPoint);
    }

    /// @notice Sets the distribution reward rate. This will also update the poolInfo.
    /// @param _tokenPerSec The number of tokens to distribute per second
    function setRewardRate(uint256 _tokenPerSec) external onlyOwner {
        massUpdatePools();
        emit RewardRateUpdated(tokenPerSec, _tokenPerSec);
        tokenPerSec = _tokenPerSec;
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[pid];

        if (block.timestamp > pool.lastRewardTimestamp) {
            uint256 lpSupply = distributorV2.poolTotalLp(pid);

            if (lpSupply > 0) {
                uint256 timeElapsed = block.timestamp -
                    pool.lastRewardTimestamp;
                uint256 tokenReward = (timeElapsed *
                    tokenPerSec *
                    pool.allocPoint) / totalAllocPoint;
                pool.accTokenPerShare += ((tokenReward * ACC_TOKEN_PRECISION) /
                    lpSupply);
            }

            pool.lastRewardTimestamp = block.timestamp;
            poolInfo[pid] = pool;
            emit UpdatePool(
                pid,
                pool.lastRewardTimestamp,
                lpSupply,
                pool.accTokenPerShare
            );
        }
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolIds.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(poolIds[pid]);
        }
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
    function onSolarReward(
        uint256 _pid,
        address _user,
        uint256 _lpAmount
    ) external override onlyDistributorV2 nonReentrant {
        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = userInfo[_pid][_user];
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
    /// @param _pid pool id.
    /// @param _user Address of user.
    /// @return pending reward for a given user.
    function pendingTokens(uint256 _pid, address _user)
        external
        view
        override
        returns (uint256 pending)
    {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = distributorV2.poolTotalLp(_pid);

        if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
            uint256 timeElapsed = block.timestamp - pool.lastRewardTimestamp;
            uint256 tokenReward = (timeElapsed *
                tokenPerSec *
                pool.allocPoint) / totalAllocPoint;
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

    /// @notice View function to see pool rewards per sec
    function poolRewardsPerSec(uint256 _pid)
        external
        view
        override
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        return (pool.allocPoint * tokenPerSec) / totalAllocPoint;
    }

    /// @notice View function to see balance of reward token.
    function balance() external view returns (uint256) {
        return _balance();
    }

    /// @notice payable function needed to receive MOVR
    receive() external payable {}
}
