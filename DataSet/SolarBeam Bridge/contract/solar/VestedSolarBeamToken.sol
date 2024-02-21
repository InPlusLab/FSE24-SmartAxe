// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/IBoringERC20.sol";
import "../libraries/BoringERC20.sol";

interface IVestedSolarBeamToken {
    function userLockedAmount(address _addr) external view returns (uint256);

    function userLockedUntil(address _addr) external view returns (uint256);

    function votingPowerUnlockTime(uint256 _value, uint256 _unlock_time)
        external
        view
        returns (uint256);

    function votingPowerLockedDays(uint256 _value, uint256 _days)
        external
        view
        returns (uint256);

    function deposit(address _addr, uint256 _value) external;

    function create(uint256 _value, uint256 _days) external;

    function increaseAmount(uint256 _value) external;

    function increaseLock(uint256 _days) external;

    function withdraw() external;
}

contract VestedSolarBeamToken is
    ERC20Burnable,
    ERC20Permit,
    IVestedSolarBeamToken,
    Ownable,
    ReentrancyGuard
{
    using BoringERC20 for IBoringERC20;

    uint256 public constant MINDAYS = 7;
    uint256 public constant MAXDAYS = 4 * 365;

    uint256 public constant MAXTIME = MAXDAYS * 1 days; // 4 years
    uint256 public constant MAX_WITHDRAWAL_PENALTY = 90000; // 90%
    uint256 public constant PRECISION = 1e5; // 5 decimals

    address public immutable lockedToken;
    address public penaltyCollector;
    uint256 public minLockedAmount;
    uint256 public earlyWithdrawPenaltyRate;

    // flags
    uint256 private _unlocked;

    struct LockedBalance {
        uint256 amount;
        uint256 end;
    }

    mapping(address => LockedBalance) public locked;
    mapping(address => uint256) public mintedForLock;

    /* ========== MODIFIERS ========== */

    modifier lock() {
        require(_unlocked == 1, "LOCKED");
        _unlocked = 0;
        _;
        _unlocked = 1;
    }

    /* =============== EVENTS ==================== */
    event Deposit(address indexed provider, uint256 value, uint256 locktime);
    event Withdraw(address indexed provider, uint256 value);
    event PenaltyCollectorSet(address indexed addr);
    event EarlyWithdrawPenaltySet(uint256 indexed penalty);
    event MinLockedAmountSet(uint256 indexed amount);

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        address _lockedToken,
        uint256 _minLockedAmount
    ) ERC20(_tokenName, _tokenSymbol) ERC20Permit(_tokenName) {
        lockedToken = _lockedToken;
        minLockedAmount = _minLockedAmount;
        earlyWithdrawPenaltyRate = 75000; // 75%
        penaltyCollector = 0x000000000000000000000000000000000000dEaD;
        _unlocked = 1;
    }

    /* ========== PUBLIC FUNCTIONS ========== */
    function userLockedAmount(address _addr)
        external
        view
        override
        returns (uint256)
    {
        return locked[_addr].amount;
    }

    function userLockedUntil(address _addr)
        external
        view
        override
        returns (uint256)
    {
        return locked[_addr].end;
    }

    function votingPowerUnlockTime(uint256 _value, uint256 _unlockTime)
        public
        view
        override
        returns (uint256)
    {
        uint256 _now = block.timestamp;
        if (_unlockTime <= _now) return 0;
        uint256 _lockedSeconds = _unlockTime - _now;
        if (_lockedSeconds >= MAXTIME) {
            return _value;
        }
        return (_value * _lockedSeconds) / MAXTIME;
    }

    function votingPowerLockedDays(uint256 _value, uint256 _days)
        public
        pure
        override
        returns (uint256)
    {
        if (_days >= MAXDAYS) {
            return _value;
        }
        return (_value * _days) / MAXDAYS;
    }

    function deposit(address _addr, uint256 _value)
        external
        override
        nonReentrant
    {
        require(_value > 0, "deposit: invalid amount");
        require(locked[_addr].amount > 0, "deposit: no lock for this address");
        _deposit(_addr, _value, 0);
    }

    function createWithPermit(
        uint256 _value,
        uint256 _days,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        require(_value >= minLockedAmount, "create: less than min amount");
        require(
            locked[_msgSender()].amount == 0,
            "create: withdraw old tokens first"
        );
        require(_days >= MINDAYS, "create: less than min amount of 7 days");
        require(_days <= MAXDAYS, "create: voting lock can be 4 years max");

        IBoringERC20(lockedToken).permit(
            _msgSender(),
            address(this),
            _value,
            deadline,
            v,
            r,
            s
        );

        _deposit(_msgSender(), _value, _days);
    }

    function create(uint256 _value, uint256 _days)
        external
        override
        nonReentrant
    {
        require(_value >= minLockedAmount, "create: less than min amount");
        require(
            locked[_msgSender()].amount == 0,
            "create: withdraw old tokens first"
        );
        require(_days >= MINDAYS, "create: less than min amount of 7 days");
        require(_days <= MAXDAYS, "create: voting lock can be 4 years max");
        _deposit(_msgSender(), _value, _days);
    }

    function increaseAmountWithPermit(
        uint256 _value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        require(_value > 0, "increaseAmount: invalid amount");

        IBoringERC20(lockedToken).permit(
            _msgSender(),
            address(this),
            _value,
            deadline,
            v,
            r,
            s
        );

        _deposit(_msgSender(), _value, 0);
    }

    function increaseAmount(uint256 _value) external override nonReentrant {
        require(_value > 0, "increaseAmount: invalid amount");
        _deposit(_msgSender(), _value, 0);
    }

    function increaseLock(uint256 _days) external override nonReentrant {
        require(_days > 0, "increaseLock: invalid amount");
        require(
            _days <= MAXDAYS,
            "increaseLock: voting lock can be 4 years max"
        );
        _deposit(_msgSender(), 0, _days);
    }

    function withdraw() external override lock {
        LockedBalance storage _locked = locked[_msgSender()];
        uint256 _now = block.timestamp;
        require(_locked.amount > 0, "withdraw: nothing to withdraw");
        require(_now >= _locked.end, "withdraw: user still locked");
        uint256 _amount = _locked.amount;
        _locked.end = 0;
        _locked.amount = 0;
        _burn(_msgSender(), mintedForLock[_msgSender()]);
        mintedForLock[_msgSender()] = 0;
        IBoringERC20(lockedToken).safeTransfer(_msgSender(), _amount);

        emit Withdraw(_msgSender(), _amount);
    }

    // This will charge PENALTY if lock is not expired yet
    function emergencyWithdraw() external lock {
        LockedBalance storage _locked = locked[_msgSender()];
        uint256 _now = block.timestamp;
        require(_locked.amount > 0, "emergencyWithdraw: nothing to withdraw");
        uint256 _amount = _locked.amount;
        if (_now < _locked.end) {
            uint256 _fee = (_amount * earlyWithdrawPenaltyRate) / PRECISION;
            _penalize(_fee);
            _amount = _amount - _fee;
        }
        _locked.end = 0;
        _locked.amount = 0;
        _burn(_msgSender(), mintedForLock[_msgSender()]);
        mintedForLock[_msgSender()] = 0;

        IBoringERC20(lockedToken).safeTransfer(_msgSender(), _amount);

        emit Withdraw(_msgSender(), _amount);
    }

    /* ========== INTERNAL FUNCTIONS ========== */
    function _deposit(
        address _addr,
        uint256 _value,
        uint256 _days
    ) internal lock {
        LockedBalance storage _locked = locked[_addr];
        uint256 _now = block.timestamp;
        uint256 _amount = _locked.amount;
        uint256 _end = _locked.end;
        uint256 _vp;
        if (_amount == 0) {
            _vp = votingPowerLockedDays(_value, _days);
            _locked.amount = _value;
            _locked.end = _now + _days * 1 days;
        } else if (_days == 0) {
            _vp = votingPowerUnlockTime(_value, _end);
            _locked.amount = _amount + _value;
        } else {
            require(
                _value == 0,
                "_deposit: cannot increase amount and extend lock in the same time"
            );
            _vp = votingPowerLockedDays(_amount, _days);
            _locked.end = _end + _days * 1 days;
            require(
                _locked.end - _now <= MAXTIME,
                "_deposit: cannot extend lock to more than 4 years"
            );
        }
        require(_vp > 0, "No benefit to lock");
        if (_value > 0) {
            IBoringERC20(lockedToken).safeTransferFrom(
                _msgSender(),
                address(this),
                _value
            );
        }
        _mint(_addr, _vp);
        mintedForLock[_addr] += _vp;

        emit Deposit(_addr, _locked.amount, _locked.end);
    }

    function _penalize(uint256 _amount) internal {
        IBoringERC20(lockedToken).safeTransfer(penaltyCollector, _amount);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */
    function setMinLockedAmount(uint256 _minLockedAmount) external onlyOwner {
        minLockedAmount = _minLockedAmount;
        emit MinLockedAmountSet(_minLockedAmount);
    }

    function setEarlyWithdrawPenaltyRate(uint256 _earlyWithdrawPenaltyRate)
        external
        onlyOwner
    {
        require(
            _earlyWithdrawPenaltyRate <= MAX_WITHDRAWAL_PENALTY,
            "setEarlyWithdrawPenaltyRate: withdrawal penalty is too high"
        ); // <= 90%
        earlyWithdrawPenaltyRate = _earlyWithdrawPenaltyRate;
        emit EarlyWithdrawPenaltySet(_earlyWithdrawPenaltyRate);
    }

    function setPenaltyCollector(address _addr) external onlyOwner {
        require(
            penaltyCollector != address(0),
            "setPenaltyCollector: set a valid address"
        );
        penaltyCollector = _addr;
        emit PenaltyCollectorSet(_addr);
    }
}
