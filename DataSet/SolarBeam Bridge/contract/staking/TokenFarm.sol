// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/IBoringERC20.sol";
import "../libraries/BoringERC20.sol";

contract TokenFarm is Ownable, ReentrancyGuard {
    using BoringERC20 for IBoringERC20;

    // Info of each user for each farm.
    struct UserInfo {
        uint256 amount; // How many Staking tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each reward distribution campaign.
    struct CampaignInfo {
        IBoringERC20 stakingToken; // Address of Staking token contract.
        IBoringERC20 rewardToken; // Address of Reward token contract
        uint256 precision; //reward token precision
        uint256 startTimestamp; // start timestamp of the campaign
        uint256 lastRewardTimestamp; // Last timestamp that Reward Token distribution occurs.
        uint256 accRewardPerShare; // Accumulated Reward Token per share. See below.
        uint256 totalStaked; // total staked amount each campaign's stake token, typically, each campaign has the same stake token, so need to track it separatedly
        uint256 totalRewards;
    }

    // Reward info
    struct RewardInfo {
        uint256 endTimestamp;
        uint256 rewardPerSec;
    }

    // @dev this is mostly used for extending reward period
    // @notice Reward info is a set of {endTimestamp, rewardPerTimestamp}
    // indexed by campaigh ID
    mapping(uint256 => RewardInfo[]) public campaignRewardInfo;

    // @notice Info of each campaign. mapped from campaigh ID
    CampaignInfo[] public campaignInfo;
    // Info of each user that stakes Staking tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // @notice limit length of reward info
    // how many phases are allowed
    uint256 public rewardInfoLimit;
    // @dev reward holder account
    address public rewardHolder;

    event Deposit(address indexed user, uint256 amount, uint256 campaign);
    event Withdraw(address indexed user, uint256 amount, uint256 campaign);
    event EmergencyWithdraw(
        address indexed user,
        uint256 amount,
        uint256 campaign
    );
    event AddCampaignInfo(
        uint256 indexed campaignID,
        IBoringERC20 stakingToken,
        IBoringERC20 rewardToken,
        uint256 startTimestamp
    );
    event AddRewardInfo(
        uint256 indexed campaignID,
        uint256 indexed phase,
        uint256 endTimestamp,
        uint256 rewardPerTimestamp
    );
    event SetRewardInfoLimit(uint256 rewardInfoLimit);
    event SetRewardHolder(address rewardHolder);

    // constructor
    constructor(address _rewardHolder) {
        rewardInfoLimit = 53;
        rewardHolder = _rewardHolder;
    }

    // @notice function for setting a reward holder who is responsible for adding a reward info
    function setRewardHolder(address _rewardHolder) external onlyOwner {
        rewardHolder = _rewardHolder;
        emit SetRewardHolder(_rewardHolder);
    }

    // @notice set new reward info limit
    function setRewardInfoLimit(uint256 _updatedRewardInfoLimit)
        external
        onlyOwner
    {
        rewardInfoLimit = _updatedRewardInfoLimit;
        emit SetRewardInfoLimit(rewardInfoLimit);
    }

    // @notice reward campaign, one campaign represents a pair of staking and reward token, last reward Timestamp and acc reward Per Share
    function addCampaignInfo(
        IBoringERC20 _stakingToken,
        IBoringERC20 _rewardToken,
        uint256 _startTimestamp
    ) external onlyOwner {
        uint256 decimalsRewardToken = uint256(_rewardToken.safeDecimals());

        require(
            decimalsRewardToken < 30,
            "constructor: reward token decimals must be inferior to 30"
        );

        uint256 precision = uint256(10**(uint256(30) - (decimalsRewardToken)));

        campaignInfo.push(
            CampaignInfo({
                stakingToken: _stakingToken,
                rewardToken: _rewardToken,
                precision: precision,
                startTimestamp: _startTimestamp,
                lastRewardTimestamp: _startTimestamp,
                accRewardPerShare: 0,
                totalStaked: 0,
                totalRewards: 0
            })
        );
        emit AddCampaignInfo(
            campaignInfo.length - 1,
            _stakingToken,
            _rewardToken,
            _startTimestamp
        );
    }

    // @notice if the new reward info is added, the reward & its end timestamp will be extended by the newly pushed reward info.
    function addRewardInfo(
        uint256 _campaignID,
        uint256 _endTimestamp,
        uint256 _rewardPerSec
    ) external onlyOwner {
        RewardInfo[] storage rewardInfo = campaignRewardInfo[_campaignID];
        CampaignInfo storage campaign = campaignInfo[_campaignID];
        require(
            rewardInfo.length < rewardInfoLimit,
            "addRewardInfo::reward info length exceeds the limit"
        );
        require(
            rewardInfo.length == 0 ||
                rewardInfo[rewardInfo.length - 1].endTimestamp >=
                block.timestamp,
            "addRewardInfo::reward period ended"
        );
        require(
            rewardInfo.length == 0 ||
                rewardInfo[rewardInfo.length - 1].endTimestamp < _endTimestamp,
            "addRewardInfo::bad new endTimestamp"
        );
        uint256 startTimestamp = rewardInfo.length == 0
            ? campaign.startTimestamp
            : rewardInfo[rewardInfo.length - 1].endTimestamp;
        uint256 timeRange = _endTimestamp - startTimestamp;
        uint256 totalRewards = _rewardPerSec * timeRange;
        campaign.rewardToken.safeTransferFrom(
            rewardHolder,
            address(this),
            totalRewards
        );
        campaign.totalRewards += totalRewards;
        rewardInfo.push(
            RewardInfo({
                endTimestamp: _endTimestamp,
                rewardPerSec: _rewardPerSec
            })
        );
        emit AddRewardInfo(
            _campaignID,
            rewardInfo.length - 1,
            _endTimestamp,
            _rewardPerSec
        );
    }

    function rewardInfoLen(uint256 _campaignID)
        external
        view
        returns (uint256)
    {
        return campaignRewardInfo[_campaignID].length;
    }

    function campaignInfoLen() external view returns (uint256) {
        return campaignInfo.length;
    }

    // @notice this will return  end block based on the current block timestamp.
    function currentEndTimestamp(uint256 _campaignID)
        external
        view
        returns (uint256)
    {
        return _endTimestampOf(_campaignID, block.timestamp);
    }

    function _endTimestampOf(uint256 _campaignID, uint256 _blockTimestamp)
        internal
        view
        returns (uint256)
    {
        RewardInfo[] memory rewardInfo = campaignRewardInfo[_campaignID];
        uint256 len = rewardInfo.length;
        if (len == 0) {
            return 0;
        }
        for (uint256 i = 0; i < len; ++i) {
            if (_blockTimestamp <= rewardInfo[i].endTimestamp)
                return rewardInfo[i].endTimestamp;
        }
        // @dev when couldn't find any reward info, it means that _blockTimestamp exceed endTimestamp
        // so return the latest reward info.
        return rewardInfo[len - 1].endTimestamp;
    }

    // @notice this will return reward per block based on the current block timestamp.
    function currentRewardPerSec(uint256 _campaignID)
        external
        view
        returns (uint256)
    {
        return _rewardPerSecOf(_campaignID, block.timestamp);
    }

    function _rewardPerSecOf(uint256 _campaignID, uint256 _blockTimestamp)
        internal
        view
        returns (uint256)
    {
        RewardInfo[] memory rewardInfo = campaignRewardInfo[_campaignID];
        uint256 len = rewardInfo.length;
        if (len == 0) {
            return 0;
        }
        for (uint256 i = 0; i < len; ++i) {
            if (_blockTimestamp <= rewardInfo[i].endTimestamp)
                return rewardInfo[i].rewardPerSec;
        }
        // @dev when couldn't find any reward info, it means that timestamp exceed endtimestamp
        // so return 0
        return 0;
    }

    // @notice Return reward multiplier over the given _from to _to timestamp.
    function getMultiplier(
        uint256 _from,
        uint256 _to,
        uint256 _endTimestamp
    ) public pure returns (uint256) {
        if ((_from >= _endTimestamp) || (_from > _to)) {
            return 0;
        }
        if (_to <= _endTimestamp) {
            return _to - _from;
        }
        return _endTimestamp - _from;
    }

    // @notice View function to see pending Reward on frontend.
    function pendingReward(uint256 _campaignID, address _user)
        external
        view
        returns (uint256)
    {
        return
            _pendingReward(
                _campaignID,
                userInfo[_campaignID][_user].amount,
                userInfo[_campaignID][_user].rewardDebt
            );
    }

    function _pendingReward(
        uint256 _campaignID,
        uint256 _amount,
        uint256 _rewardDebt
    ) internal view returns (uint256) {
        CampaignInfo memory campaign = campaignInfo[_campaignID];
        RewardInfo[] memory rewardInfo = campaignRewardInfo[_campaignID];
        uint256 accRewardPerShare = campaign.accRewardPerShare;
        if (
            block.timestamp > campaign.lastRewardTimestamp &&
            campaign.totalStaked != 0
        ) {
            uint256 cursor = campaign.lastRewardTimestamp;
            for (uint256 i = 0; i < rewardInfo.length; ++i) {
                uint256 multiplier = getMultiplier(
                    cursor,
                    block.timestamp,
                    rewardInfo[i].endTimestamp
                );
                if (multiplier == 0) continue;
                cursor = rewardInfo[i].endTimestamp;
                accRewardPerShare +=
                    ((multiplier * rewardInfo[i].rewardPerSec) *
                        campaign.precision) /
                    campaign.totalStaked;
            }
        }
        return
            ((_amount * accRewardPerShare) / campaign.precision) - _rewardDebt;
    }

    function updateCampaign(uint256 _campaignID) external nonReentrant {
        _updateCampaign(_campaignID);
    }

    // @notice Update reward variables of the given campaign to be up-to-date.
    function _updateCampaign(uint256 _campaignID) internal {
        CampaignInfo storage campaign = campaignInfo[_campaignID];
        RewardInfo[] memory rewardInfo = campaignRewardInfo[_campaignID];
        if (block.timestamp <= campaign.lastRewardTimestamp) {
            return;
        }
        if (campaign.totalStaked == 0) {
            // if there is no total supply, return and use the campaign's start block timestamp as the last reward block timestamp
            // so that ALL reward will be distributed.
            // however, if the first deposit is out of reward period, last reward block will be its block timestamp
            // in order to keep the multiplier = 0
            if (
                block.timestamp > _endTimestampOf(_campaignID, block.timestamp)
            ) {
                campaign.lastRewardTimestamp = block.timestamp;
            }
            return;
        }
        // @dev for each reward info
        for (uint256 i = 0; i < rewardInfo.length; ++i) {
            // @dev get multiplier based on current Block and rewardInfo's end block
            // multiplier will be a range of either (current block - campaign.lastRewardBlock)
            // or (reward info's endblock - campaign.lastRewardTimestamp) or 0
            uint256 multiplier = getMultiplier(
                campaign.lastRewardTimestamp,
                block.timestamp,
                rewardInfo[i].endTimestamp
            );
            if (multiplier == 0) continue;
            // @dev if currentTimestamp exceed end block, use end block as the last reward block
            // so that for the next iteration, previous endTimestamp will be used as the last reward block
            if (block.timestamp > rewardInfo[i].endTimestamp) {
                campaign.lastRewardTimestamp = rewardInfo[i].endTimestamp;
            } else {
                campaign.lastRewardTimestamp = block.timestamp;
            }
            campaign.accRewardPerShare +=
                ((multiplier * rewardInfo[i].rewardPerSec) *
                    campaign.precision) /
                campaign.totalStaked;
        }
    }

    // @notice Update reward variables for all campaigns. gas spending is HIGH in this method call, BE CAREFUL
    function massUpdateCampaigns() external nonReentrant {
        uint256 length = campaignInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            _updateCampaign(pid);
        }
    }

    function depositWithPermit(
        uint256 _campaignID,
        uint256 _amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        CampaignInfo storage campaign = campaignInfo[_campaignID];
        campaign.stakingToken.permit(
            msg.sender,
            address(this),
            _amount,
            deadline,
            v,
            r,
            s
        );
        _deposit(_campaignID, _amount);
    }

    // @notice Stake Staking tokens to TokenFarm
    function deposit(uint256 _campaignID, uint256 _amount)
        external
        nonReentrant
    {
        _deposit(_campaignID, _amount);
    }

    // @notice Stake Staking tokens to TokenFarm
    function _deposit(uint256 _campaignID, uint256 _amount) internal {
        CampaignInfo storage campaign = campaignInfo[_campaignID];
        UserInfo storage user = userInfo[_campaignID][msg.sender];
        _updateCampaign(_campaignID);
        if (user.amount > 0) {
            uint256 pending = ((user.amount * campaign.accRewardPerShare) /
                campaign.precision) - user.rewardDebt;
            if (pending > 0) {
                campaign.rewardToken.safeTransfer(address(msg.sender), pending);
            }
        }
        if (_amount > 0) {
            campaign.stakingToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount += _amount;
            campaign.totalStaked += _amount;
        }
        user.rewardDebt =
            (user.amount * campaign.accRewardPerShare) /
            campaign.precision;
        emit Deposit(msg.sender, _amount, _campaignID);
    }

    // @notice Withdraw Staking tokens from STAKING.
    function withdraw(uint256 _campaignID, uint256 _amount)
        external
        nonReentrant
    {
        _withdraw(_campaignID, _amount);
    }

    // @notice internal method for withdraw (withdraw and harvest method depend on this method)
    function _withdraw(uint256 _campaignID, uint256 _amount) internal {
        CampaignInfo storage campaign = campaignInfo[_campaignID];
        UserInfo storage user = userInfo[_campaignID][msg.sender];
        require(user.amount >= _amount, "withdraw::bad withdraw amount");
        _updateCampaign(_campaignID);
        uint256 pending = ((user.amount * campaign.accRewardPerShare) /
            campaign.precision) - user.rewardDebt;
        if (pending > 0) {
            campaign.rewardToken.safeTransfer(address(msg.sender), pending);
        }
        if (_amount > 0) {
            user.amount -= _amount;
            campaign.stakingToken.safeTransfer(address(msg.sender), _amount);
            campaign.totalStaked -= _amount;
        }
        user.rewardDebt =
            (user.amount * campaign.accRewardPerShare) /
            campaign.precision;

        emit Withdraw(msg.sender, _amount, _campaignID);
    }

    // @notice method for harvest campaigns (used when the user want to claim their reward token based on specified campaigns)
    function harvest(uint256[] calldata _campaignIDs) external nonReentrant {
        for (uint256 i = 0; i < _campaignIDs.length; ++i) {
            _withdraw(_campaignIDs[i], 0);
        }
    }

    // @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _campaignID) external nonReentrant {
        CampaignInfo storage campaign = campaignInfo[_campaignID];
        UserInfo storage user = userInfo[_campaignID][msg.sender];
        uint256 _amount = user.amount;
        campaign.totalStaked -= _amount;
        user.amount = 0;
        user.rewardDebt = 0;
        campaign.stakingToken.safeTransfer(address(msg.sender), _amount);
        emit EmergencyWithdraw(msg.sender, _amount, _campaignID);
    }

    // @notice Withdraw reward. EMERGENCY ONLY.
    function emergencyRewardWithdraw(
        uint256 _campaignID,
        uint256 _amount,
        address _beneficiary
    ) external onlyOwner nonReentrant {
        CampaignInfo storage campaign = campaignInfo[_campaignID];
        uint256 currentStakingPendingReward = _pendingReward(
            _campaignID,
            campaign.totalStaked,
            0
        );
        require(
            currentStakingPendingReward + _amount <= campaign.totalRewards,
            "emergencyRewardWithdraw::not enough reward token"
        );
        campaign.totalRewards -= _amount;
        campaign.rewardToken.safeTransfer(_beneficiary, _amount);
    }
}
