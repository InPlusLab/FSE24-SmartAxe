// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./rewarders/IComplexRewarder.sol";
import "./libraries/BoringERC20.sol";
import "./ISolarPair.sol";

contract SolarDistributorV2 is Ownable, ReentrancyGuard {
    using BoringERC20 for IBoringERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardLockedUp; // Reward locked up.
        uint256 nextHarvestUntil; // When can the user harvest again.
    }

    // Info of each pool.
    struct PoolInfo {
        IBoringERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Solar to distribute per block.
        uint256 lastRewardTimestamp; // Last block number that Solar distribution occurs.
        uint256 accSolarPerShare; // Accumulated Solar per share, times 1e18. See below.
        uint16 depositFeeBP; // Deposit fee in basis points
        uint256 harvestInterval; // Harvest interval in seconds
        uint256 totalLp; // Total token in Pool
        IComplexRewarder[] rewarders; // Array of rewarder contract for pools with incentives
    }

    IBoringERC20 public solar;

    // Solar tokens created per second
    uint256 public solarPerSec;

    // Max harvest interval: 14 days
    uint256 public constant MAXIMUM_HARVEST_INTERVAL = 14 days;

    // Maximum deposit fee rate: 10%
    uint16 public constant MAXIMUM_DEPOSIT_FEE_RATE = 1000;

    // Info of each pool
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    // The timestamp when Solar mining starts.
    uint256 public startTimestamp;

    // Total locked up rewards
    uint256 public totalLockedUpRewards;

    // Total Solar in Solar Pools (can be multiple pools)
    uint256 public totalSolarInPools = 0;

    // Team address.
    address public teamAddress;

    // Treasury address.
    address public treasuryAddress;

    // Investor address.
    address public investorAddress;

    // Percentage of pool rewards that goto the team.
    uint256 public teamPercent;

    // Percentage of pool rewards that goes to the treasury.
    uint256 public treasuryPercent;

    // Percentage of pool rewards that goes to the investor.
    uint256 public investorPercent;

    // The precision factor
    uint256 private immutable ACC_TOKEN_PRECISION = 1e12;

    modifier validatePoolByPid(uint256 _pid) {
        require(_pid < poolInfo.length, "Pool does not exist");
        _;
    }

    event Add(
        uint256 indexed pid,
        uint256 allocPoint,
        IBoringERC20 indexed lpToken,
        uint16 depositFeeBP,
        uint256 harvestInterval,
        IComplexRewarder[] indexed rewarders
    );

    event Set(
        uint256 indexed pid,
        uint256 allocPoint,
        uint16 depositFeeBP,
        uint256 harvestInterval,
        IComplexRewarder[] indexed rewarders
    );

    event UpdatePool(
        uint256 indexed pid,
        uint256 lastRewardTimestamp,
        uint256 lpSupply,
        uint256 accSolarPerShare
    );

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);

    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    event EmissionRateUpdated(
        address indexed caller,
        uint256 previousValue,
        uint256 newValue
    );

    event RewardLockedUp(
        address indexed user,
        uint256 indexed pid,
        uint256 amountLockedUp
    );

    event AllocPointsUpdated(
        address indexed caller,
        uint256 previousAmount,
        uint256 newAmount
    );

    event SetTeamAddress(
        address indexed oldAddress,
        address indexed newAddress
    );

    event SetTreasuryAddress(
        address indexed oldAddress,
        address indexed newAddress
    );

    event SetInvestorAddress(
        address indexed oldAddress,
        address indexed newAddress
    );

    event SetTeamPercent(uint256 oldPercent, uint256 newPercent);

    event SetTreasuryPercent(uint256 oldPercent, uint256 newPercent);

    event SetInvestorPercent(uint256 oldPercent, uint256 newPercent);

    constructor(
        IBoringERC20 _solar,
        uint256 _solarPerSec,
        address _teamAddress,
        address _treasuryAddress,
        address _investorAddress,
        uint256 _teamPercent,
        uint256 _treasuryPercent,
        uint256 _investorPercent
    ) {
        require(
            _teamPercent <= 1000,
            "constructor: invalid team percent value"
        );
        require(
            _treasuryPercent <= 1000,
            "constructor: invalid treasury percent value"
        );
        require(
            _investorPercent <= 1000,
            "constructor: invalid investor percent value"
        );
        require(
            _teamPercent + _treasuryPercent + _investorPercent <= 1000,
            "constructor: total percent over max"
        );

        //StartBlock always many years later from contract const ruct, will be set later in StartFarming function
        startTimestamp = block.timestamp + (60 * 60 * 24 * 365);

        solar = _solar;
        solarPerSec = _solarPerSec;

        teamAddress = _teamAddress;
        treasuryAddress = _treasuryAddress;
        investorAddress = _investorAddress;

        teamPercent = _teamPercent;
        treasuryPercent = _treasuryPercent;
        investorPercent = _investorPercent;
    }

    // Set farming start, can call only once
    function startFarming() public onlyOwner {
        require(
            block.timestamp < startTimestamp,
            "start farming: farm started already"
        );

        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            pool.lastRewardTimestamp = block.timestamp;
        }

        startTimestamp = block.timestamp;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // Can add multiple pool with same lp token without messing up rewards, because each pool's balance is tracked using its own totalLp
    function add(
        uint256 _allocPoint,
        IBoringERC20 _lpToken,
        uint16 _depositFeeBP,
        uint256 _harvestInterval,
        IComplexRewarder[] calldata _rewarders
    ) public onlyOwner {
        require(_rewarders.length <= 10, "add: too many rewarders");
        require(
            _depositFeeBP <= MAXIMUM_DEPOSIT_FEE_RATE,
            "add: deposit fee too high"
        );
        require(
            _harvestInterval <= MAXIMUM_HARVEST_INTERVAL,
            "add: invalid harvest interval"
        );
        require(
            Address.isContract(address(_lpToken)),
            "add: LP token must be a valid contract"
        );

        for (
            uint256 rewarderId = 0;
            rewarderId < _rewarders.length;
            ++rewarderId
        ) {
            require(
                Address.isContract(address(_rewarders[rewarderId])),
                "add: rewarder must be contract"
            );
        }

        _massUpdatePools();

        uint256 lastRewardTimestamp = block.timestamp > startTimestamp
            ? block.timestamp
            : startTimestamp;

        totalAllocPoint += _allocPoint;

        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardTimestamp: lastRewardTimestamp,
                accSolarPerShare: 0,
                depositFeeBP: _depositFeeBP,
                harvestInterval: _harvestInterval,
                totalLp: 0,
                rewarders: _rewarders
            })
        );

        emit Add(
            poolInfo.length - 1,
            _allocPoint,
            _lpToken,
            _depositFeeBP,
            _harvestInterval,
            _rewarders
        );
    }

    // Update the given pool's Solar allocation point and deposit fee. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint16 _depositFeeBP,
        uint256 _harvestInterval,
        IComplexRewarder[] calldata _rewarders
    ) public onlyOwner validatePoolByPid(_pid) {
        require(_rewarders.length <= 10, "set: too many rewarders");

        require(
            _depositFeeBP <= MAXIMUM_DEPOSIT_FEE_RATE,
            "set: deposit fee too high"
        );
        require(
            _harvestInterval <= MAXIMUM_HARVEST_INTERVAL,
            "set: invalid harvest interval"
        );

        for (
            uint256 rewarderId = 0;
            rewarderId < _rewarders.length;
            ++rewarderId
        ) {
            require(
                Address.isContract(address(_rewarders[rewarderId])),
                "set: rewarder must be contract"
            );
        }

        _massUpdatePools();

        totalAllocPoint =
            totalAllocPoint -
            poolInfo[_pid].allocPoint +
            _allocPoint;

        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
        poolInfo[_pid].harvestInterval = _harvestInterval;
        poolInfo[_pid].rewarders = _rewarders;

        emit Set(
            _pid,
            _allocPoint,
            _depositFeeBP,
            _harvestInterval,
            _rewarders
        );
    }

    // View function to see pending rewards on frontend.
    function pendingTokens(uint256 _pid, address _user)
        external
        view
        validatePoolByPid(_pid)
        returns (
            address[] memory addresses,
            string[] memory symbols,
            uint256[] memory decimals,
            uint256[] memory amounts
        )
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accSolarPerShare = pool.accSolarPerShare;
        uint256 lpSupply = pool.totalLp;

        if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
            uint256 multiplier = block.timestamp - pool.lastRewardTimestamp;
            uint256 total = 1000;
            uint256 lpPercent = total -
                teamPercent -
                treasuryPercent -
                investorPercent;

            uint256 solarReward = (multiplier *
                solarPerSec *
                pool.allocPoint *
                lpPercent) /
                totalAllocPoint /
                total;

            accSolarPerShare += (
                ((solarReward * ACC_TOKEN_PRECISION) / lpSupply)
            );
        }

        uint256 pendingSolar = (((user.amount * accSolarPerShare) /
            ACC_TOKEN_PRECISION) - user.rewardDebt) + user.rewardLockedUp;

        addresses = new address[](pool.rewarders.length + 1);
        symbols = new string[](pool.rewarders.length + 1);
        amounts = new uint256[](pool.rewarders.length + 1);
        decimals = new uint256[](pool.rewarders.length + 1);

        addresses[0] = address(solar);
        symbols[0] = IBoringERC20(solar).safeSymbol();
        decimals[0] = IBoringERC20(solar).safeDecimals();
        amounts[0] = pendingSolar;

        for (
            uint256 rewarderId = 0;
            rewarderId < pool.rewarders.length;
            ++rewarderId
        ) {
            addresses[rewarderId + 1] = address(
                pool.rewarders[rewarderId].rewardToken()
            );

            symbols[rewarderId + 1] = IBoringERC20(
                pool.rewarders[rewarderId].rewardToken()
            ).safeSymbol();

            decimals[rewarderId + 1] = IBoringERC20(
                pool.rewarders[rewarderId].rewardToken()
            ).safeDecimals();

            amounts[rewarderId + 1] = pool.rewarders[rewarderId].pendingTokens(
                _pid,
                _user
            );
        }
    }

    /// @notice View function to see pool rewards per sec
    function poolRewardsPerSec(uint256 _pid)
        external
        view
        validatePoolByPid(_pid)
        returns (
            address[] memory addresses,
            string[] memory symbols,
            uint256[] memory decimals,
            uint256[] memory rewardsPerSec
        )
    {
        PoolInfo storage pool = poolInfo[_pid];

        addresses = new address[](pool.rewarders.length + 1);
        symbols = new string[](pool.rewarders.length + 1);
        decimals = new uint256[](pool.rewarders.length + 1);
        rewardsPerSec = new uint256[](pool.rewarders.length + 1);

        addresses[0] = address(solar);
        symbols[0] = IBoringERC20(solar).safeSymbol();
        decimals[0] = IBoringERC20(solar).safeDecimals();

        uint256 total = 1000;
        uint256 lpPercent = total -
            teamPercent -
            treasuryPercent -
            investorPercent;

        rewardsPerSec[0] =
            (pool.allocPoint * solarPerSec * lpPercent) /
            totalAllocPoint /
            total;

        for (
            uint256 rewarderId = 0;
            rewarderId < pool.rewarders.length;
            ++rewarderId
        ) {
            addresses[rewarderId + 1] = address(
                pool.rewarders[rewarderId].rewardToken()
            );

            symbols[rewarderId + 1] = IBoringERC20(
                pool.rewarders[rewarderId].rewardToken()
            ).safeSymbol();

            decimals[rewarderId + 1] = IBoringERC20(
                pool.rewarders[rewarderId].rewardToken()
            ).safeDecimals();

            rewardsPerSec[rewarderId + 1] = pool
                .rewarders[rewarderId]
                .poolRewardsPerSec(_pid);
        }
    }

    // View function to see rewarders for a pool
    function poolRewarders(uint256 _pid)
        external
        view
        validatePoolByPid(_pid)
        returns (address[] memory rewarders)
    {
        PoolInfo storage pool = poolInfo[_pid];
        rewarders = new address[](pool.rewarders.length);
        for (
            uint256 rewarderId = 0;
            rewarderId < pool.rewarders.length;
            ++rewarderId
        ) {
            rewarders[rewarderId] = address(pool.rewarders[rewarderId]);
        }
    }

    // View function to see if user can harvest Solar.
    function canHarvest(uint256 _pid, address _user)
        public
        view
        validatePoolByPid(_pid)
        returns (bool)
    {
        UserInfo storage user = userInfo[_pid][_user];
        return
            block.timestamp >= startTimestamp &&
            block.timestamp >= user.nextHarvestUntil;
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() external nonReentrant {
        _massUpdatePools();
    }

    // Internal method for massUpdatePools
    function _massUpdatePools() internal {
        for (uint256 pid = 0; pid < poolInfo.length; ++pid) {
            _updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) external nonReentrant {
        _updatePool(_pid);
    }

    // Internal method for _updatePool
    function _updatePool(uint256 _pid) internal validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];

        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }

        uint256 lpSupply = pool.totalLp;

        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }

        uint256 multiplier = block.timestamp - pool.lastRewardTimestamp;

        uint256 solarReward = ((multiplier * solarPerSec) * pool.allocPoint) /
            totalAllocPoint;

        uint256 total = 1000;
        uint256 lpPercent = total -
            teamPercent -
            treasuryPercent -
            investorPercent;

        solar.mint(teamAddress, (solarReward * teamPercent) / total);
        solar.mint(treasuryAddress, (solarReward * treasuryPercent) / total);
        solar.mint(investorAddress, (solarReward * investorPercent) / total);
        solar.mint(address(this), (solarReward * lpPercent) / total);

        pool.accSolarPerShare +=
            (solarReward * ACC_TOKEN_PRECISION * lpPercent) /
            pool.totalLp /
            total;

        pool.lastRewardTimestamp = block.timestamp;

        emit UpdatePool(
            _pid,
            pool.lastRewardTimestamp,
            lpSupply,
            pool.accSolarPerShare
        );
    }

    function depositWithPermit(
        uint256 pid,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public nonReentrant validatePoolByPid(pid) {
        PoolInfo storage pool = poolInfo[pid];
        ISolarPair pair = ISolarPair(address(pool.lpToken));
        pair.permit(msg.sender, address(this), amount, deadline, v, r, s);
        _deposit(pid, amount);
    }

    // Deposit tokens for Solar allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        _deposit(_pid, _amount);
    }

    // Deposit tokens for Solar allocation.
    function _deposit(uint256 _pid, uint256 _amount)
        internal
        validatePoolByPid(_pid)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        _updatePool(_pid);

        payOrLockupPendingSolar(_pid);

        if (_amount > 0) {
            uint256 beforeDeposit = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);
            uint256 afterDeposit = pool.lpToken.balanceOf(address(this));

            _amount = afterDeposit - beforeDeposit;

            if (pool.depositFeeBP > 0) {
                uint256 depositFee = (_amount * pool.depositFeeBP) / 10000;
                pool.lpToken.safeTransfer(treasuryAddress, depositFee);

                _amount = _amount - depositFee;
            }

            user.amount += _amount;

            if (address(pool.lpToken) == address(solar)) {
                totalSolarInPools += _amount;
            }
        }
        user.rewardDebt =
            (user.amount * pool.accSolarPerShare) /
            ACC_TOKEN_PRECISION;

        for (
            uint256 rewarderId = 0;
            rewarderId < pool.rewarders.length;
            ++rewarderId
        ) {
            pool.rewarders[rewarderId].onSolarReward(
                _pid,
                msg.sender,
                user.amount
            );
        }

        if (_amount > 0) {
            pool.totalLp += _amount;
        }

        emit Deposit(msg.sender, _pid, _amount);
    }

    //withdraw tokens
    function withdraw(uint256 _pid, uint256 _amount)
        public
        nonReentrant
        validatePoolByPid(_pid)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        //this will make sure that user can only withdraw from his pool
        require(user.amount >= _amount, "withdraw: user amount not enough");

        //cannot withdraw more than pool's balance
        require(pool.totalLp >= _amount, "withdraw: pool total not enough");

        _updatePool(_pid);

        payOrLockupPendingSolar(_pid);

        if (_amount > 0) {
            user.amount -= _amount;
            if (address(pool.lpToken) == address(solar)) {
                totalSolarInPools -= _amount;
            }
            pool.lpToken.safeTransfer(msg.sender, _amount);
        }

        user.rewardDebt =
            (user.amount * pool.accSolarPerShare) /
            ACC_TOKEN_PRECISION;

        for (
            uint256 rewarderId = 0;
            rewarderId < pool.rewarders.length;
            ++rewarderId
        ) {
            pool.rewarders[rewarderId].onSolarReward(
                _pid,
                msg.sender,
                user.amount
            );
        }

        if (_amount > 0) {
            pool.totalLp -= _amount;
        }

        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;

        //Cannot withdraw more than pool's balance
        require(
            pool.totalLp >= amount,
            "emergency withdraw: pool total not enough"
        );

        user.amount = 0;
        user.rewardDebt = 0;
        user.rewardLockedUp = 0;
        user.nextHarvestUntil = 0;
        pool.totalLp -= amount;

        for (
            uint256 rewarderId = 0;
            rewarderId < pool.rewarders.length;
            ++rewarderId
        ) {
            pool.rewarders[rewarderId].onSolarReward(_pid, msg.sender, 0);
        }

        if (address(pool.lpToken) == address(solar)) {
            totalSolarInPools -= amount;
        }

        pool.lpToken.safeTransfer(msg.sender, amount);

        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Pay or lockup pending Solar.
    function payOrLockupPendingSolar(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.nextHarvestUntil == 0 && block.timestamp >= startTimestamp) {
            user.nextHarvestUntil = block.timestamp + pool.harvestInterval;
        }

        uint256 pending = ((user.amount * pool.accSolarPerShare) /
            ACC_TOKEN_PRECISION) - user.rewardDebt;

        if (canHarvest(_pid, msg.sender)) {
            if (pending > 0 || user.rewardLockedUp > 0) {
                uint256 pendingRewards = pending + user.rewardLockedUp;

                // reset lockup
                totalLockedUpRewards -= user.rewardLockedUp;
                user.rewardLockedUp = 0;
                user.nextHarvestUntil = block.timestamp + pool.harvestInterval;

                // send rewards
                safeSolarTransfer(msg.sender, pendingRewards);
            }
        } else if (pending > 0) {
            totalLockedUpRewards += pending;
            user.rewardLockedUp += pending;
            emit RewardLockedUp(msg.sender, _pid, pending);
        }
    }

    // Safe Solar transfer function, just in case if rounding error causes pool do not have enough Solar.
    function safeSolarTransfer(address _to, uint256 _amount) internal {
        if (solar.balanceOf(address(this)) > totalSolarInPools) {
            //solarBal = total Solar in SolarDistributor - total Solar in Solar pools, this will make sure that SolarDistributor never transfer rewards from deposited Solar pools
            uint256 solarBal = solar.balanceOf(address(this)) -
                totalSolarInPools;
            if (_amount >= solarBal) {
                solar.safeTransfer(_to, solarBal);
            } else if (_amount > 0) {
                solar.safeTransfer(_to, _amount);
            }
        }
    }

    function updateEmissionRate(uint256 _solarPerSec) public onlyOwner {
        _massUpdatePools();

        emit EmissionRateUpdated(msg.sender, solarPerSec, _solarPerSec);

        solarPerSec = _solarPerSec;
    }

    function updateAllocPoint(uint256 _pid, uint256 _allocPoint)
        public
        onlyOwner
    {
        _massUpdatePools();

        emit AllocPointsUpdated(
            msg.sender,
            poolInfo[_pid].allocPoint,
            _allocPoint
        );

        totalAllocPoint =
            totalAllocPoint -
            poolInfo[_pid].allocPoint +
            _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function poolTotalLp(uint256 pid) external view returns (uint256) {
        return poolInfo[pid].totalLp;
    }

    // Function to harvest many pools in a single transaction
    function harvestMany(uint256[] calldata _pids) public nonReentrant {
        require(_pids.length <= 30, "harvest many: too many pool ids");
        for (uint256 index = 0; index < _pids.length; ++index) {
            _deposit(_pids[index], 0);
        }
    }

    // Update team address by the previous team address.
    function setTeamAddress(address _teamAddress) public {
        require(
            msg.sender == teamAddress,
            "set team address: only previous team address can call this method"
        );
        require(
            _teamAddress != address(0),
            "set team address: invalid new team address"
        );
        teamAddress = _teamAddress;
        emit SetTeamAddress(msg.sender, _teamAddress);
    }

    function setTeamPercent(uint256 _newTeamPercent) public onlyOwner {
        require(
            _newTeamPercent <= 1000,
            "set team percent: invalid percent value"
        );
        require(
            treasuryPercent + _newTeamPercent + investorPercent <= 1000,
            "set team percent: total percent over max"
        );
        emit SetTeamPercent(teamPercent, _newTeamPercent);
        teamPercent = _newTeamPercent;
    }

    // Update treasury address by the previous treasury.
    function setTreasuryAddress(address _treasuryAddress) public {
        require(
            msg.sender == treasuryAddress,
            "set treasury address: only previous treasury address can call this method"
        );
        require(
            _treasuryAddress != address(0),
            "set treasury address: invalid new treasury address"
        );
        treasuryAddress = _treasuryAddress;
        emit SetTreasuryAddress(msg.sender, _treasuryAddress);
    }

    function setTreasuryPercent(uint256 _newTreasuryPercent) public onlyOwner {
        require(
            _newTreasuryPercent <= 1000,
            "set treasury percent: invalid percent value"
        );
        require(
            teamPercent + _newTreasuryPercent + investorPercent <= 1000,
            "set treasury percent: total percent over max"
        );
        emit SetTreasuryPercent(treasuryPercent, _newTreasuryPercent);
        treasuryPercent = _newTreasuryPercent;
    }

    // Update the investor address by the previous investor.
    function setInvestorAddress(address _investorAddress) public {
        require(
            msg.sender == investorAddress,
            "set investor address: only previous investor can call this method"
        );
        require(
            _investorAddress != address(0),
            "set investor address: invalid new investor address"
        );
        investorAddress = _investorAddress;
        emit SetInvestorAddress(msg.sender, _investorAddress);
    }

    function setInvestorPercent(uint256 _newInvestorPercent) public onlyOwner {
        require(
            _newInvestorPercent <= 1000,
            "set investor percent: invalid percent value"
        );
        require(
            teamPercent + _newInvestorPercent + treasuryPercent <= 1000,
            "set investor percent: total percent over max"
        );
        emit SetInvestorPercent(investorPercent, _newInvestorPercent);
        investorPercent = _newInvestorPercent;
    }
}
