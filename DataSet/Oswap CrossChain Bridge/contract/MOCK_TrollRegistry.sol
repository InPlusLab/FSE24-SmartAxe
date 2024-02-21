// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Authorization.sol";
import "./OSWAP_BridgeVaultTrollRegistry.sol";
import "./OSWAP_ConfigStore.sol";
import "./OSWAP_VotingManager.sol";

contract MOCK_TrollRegistry is Authorization {
    using SafeERC20 for IERC20;

    // onlyOwner
    modifier onlyVoting() {
        require(msg.sender == owner);
        _;
    }
    modifier whenPaused() {
        require(paused(), "NOT PAUSED!");
        _;
    }
    modifier whenNotPaused() {
        require(!paused(), "PAUSED!");
        _;
    }

    event Shutdown(address indexed account);
    event Resume();

    event AddTroll(address indexed troll, uint256 indexed trollProfileIndex, bool isSuperTroll);
    event UpdateTroll(uint256 indexed trollProfileIndex, address indexed oldTroll, address indexed newTroll);
    event RemoveTroll(uint256 indexed trollProfileIndex);
    event DelistTroll(uint256 indexed trollProfileIndex);
    event LockSuperTroll(uint256 indexed trollProfileIndex, address lockedBy);
    event LockGeneralTroll(uint256 indexed trollProfileIndex, address lockedBy);
    event UnlockSuperTroll(uint256 indexed trollProfileIndex, bool unlock, address bridgeVault, uint256 penalty);
    event UnlockGeneralTroll(uint256 indexed trollProfileIndex);
    event UpdateConfigStore(OSWAP_ConfigStore newConfigStore);
    event SetVotingExecutor(address newVotingExecutor, bool isActive);
    event Upgrade(address newTrollRegistry);

    enum TrollType {NotSpecified, SuperTroll, GeneralTroll, BlockedSuperTroll, BlockedGeneralTroll}

    struct TrollProfile {
        address troll;
        TrollType trollType;
    }

    bool private _paused;
    IERC20 public immutable govToken;
    OSWAP_ConfigStore public configStore;
    address public immutable trollRegistry = address(this);

    mapping(uint256 => TrollProfile) public trollProfiles; // trollProfiles[trollProfileIndex] = {troll, trollType}
    mapping(address => uint256) public trollProfileInv; // trollProfileInv[troll] = trollProfileIndex

    uint256 public superTrollCount;
    uint256 public generalTrollCount;

    mapping(uint256 => bool) public usedNonce;

    address public newTrollRegistry;

    constructor(IERC20 _govToken) {
        govToken = _govToken;
        isPermitted[msg.sender] = true;
        _setVotingExecutor(msg.sender, true);
    }
    function initAddress(OSWAP_ConfigStore _configStore) external onlyOwner {
        require(address(_configStore) != address(0), "null address");
        require(address(configStore) == address(0), "already set");
        configStore = _configStore;

        // renounceOwnership();
    }

    /*
     * upgrade
     */
    function updateConfigStore() external {
        OSWAP_ConfigStore _configStore = configStore.newConfigStore();
        require(address(_configStore) != address(0), "Invalid config store");
        configStore = _configStore;
        emit UpdateConfigStore(configStore);
    }

    function upgradeTrollRegistry(address _trollRegistry) external onlyVoting {
        _upgradeTrollRegistry(_trollRegistry);
    }
    function upgradeTrollRegistryByAdmin(address _trollRegistry) external onlyOwner {
        _upgradeTrollRegistry(_trollRegistry);
    }
    function _upgradeTrollRegistry(address _trollRegistry) internal {
        // require(address(newTrollRegistry) == address(0), "already set");
        newTrollRegistry = _trollRegistry;
        emit Upgrade(_trollRegistry);
    }

    /*
     * pause / resume
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }
    function shutdownByAdmin() external auth whenNotPaused {
        _paused = true;
        emit Shutdown(msg.sender);
    }
    function shutdownByVoting() external onlyVoting whenNotPaused {
        _paused = true;
        emit Shutdown(msg.sender);
    }
    function resume() external onlyVoting whenPaused {
        _paused = false;
        emit Resume();
    }

    function isSuperTroll(address troll, bool returnFalseIfBlocked) public view returns (bool) {
        uint256 index = trollProfileInv[troll];
        return isSuperTrollByIndex(index, returnFalseIfBlocked);
    }
    function isSuperTrollByIndex(uint256 trollProfileIndex, bool returnFalseIfBlocked) public view returns (bool) {
        return trollProfiles[trollProfileIndex].trollType == TrollType.SuperTroll ||
               (trollProfiles[trollProfileIndex].trollType == TrollType.BlockedSuperTroll && !returnFalseIfBlocked);
    }
    function isGeneralTroll(address troll, bool returnFalseIfBlocked) public view returns (bool) {
        uint256 index = trollProfileInv[troll];
        return isGeneralTrollByIndex(index, returnFalseIfBlocked);
    }
    function isGeneralTrollByIndex(uint256 trollProfileIndex, bool returnFalseIfBlocked) public view returns (bool) {
        return trollProfiles[trollProfileIndex].trollType == TrollType.GeneralTroll ||
               (trollProfiles[trollProfileIndex].trollType == TrollType.BlockedGeneralTroll && !returnFalseIfBlocked);
    }

    /*
    function verifySignatures(address msgSender, bytes[] calldata signatures, bytes32 paramsHash, uint256 _nonce) public {
    function hashAddTroll(uint256 trollProfileIndex, address troll, bool _isSuperTroll, uint256 _nonce) public view returns (bytes32) {
    function hashUpdateTroll(uint256 trollProfileIndex, address newTroll, uint256 _nonce) public view returns (bytes32) {
    function hashRemoveTroll(uint256 trollProfileIndex, uint256 _nonce) public view returns (bytes32) {
    function hashUnlockTroll(uint256 trollProfileIndex, bool unlock, address[] memory vaultRegistry, uint256[] memory penalty, uint256 _nonce) public view returns (bytes32) {
    */
    function addTroll(bytes[] calldata signatures, uint256 trollProfileIndex, address troll, bool _isSuperTroll, uint256 _nonce) external onlyOwner {
        signatures;
        _nonce;
        require(trollProfiles[trollProfileIndex].trollType == TrollType.NotSpecified, "already added");
        trollProfiles[trollProfileIndex] = TrollProfile({troll:troll, trollType:_isSuperTroll ? TrollType.SuperTroll : TrollType.GeneralTroll});
        trollProfileInv[troll] = trollProfileIndex;
        if (trollProfiles[trollProfileIndex].trollType == TrollType.SuperTroll) {
            superTrollCount++;
        } else if (trollProfiles[trollProfileIndex].trollType == TrollType.SuperTroll) {
            generalTrollCount++;
        }
        emit AddTroll(troll, trollProfileIndex, _isSuperTroll);

    }
    function updateTroll(bytes[] calldata signatures, uint256 trollProfileIndex, address newTroll, uint256 _nonce) external onlyOwner {
        signatures;
        _nonce;
        address troll = trollProfiles[trollProfileIndex].troll;
        require(troll !=  address(0), "not exists");
        delete trollProfileInv[troll];
        trollProfiles[trollProfileIndex].troll = newTroll;
        trollProfileInv[newTroll] = trollProfileIndex;
        emit UpdateTroll(trollProfileIndex, troll, newTroll);
    }
    function removeTroll(bytes[] calldata signatures, uint256 trollProfileIndex, uint256 _nonce) external onlyOwner {
        signatures;
        _nonce;
        TrollProfile storage troll = trollProfiles[trollProfileIndex];
        require(troll.trollType != TrollType.NotSpecified, "not a valid troll");
        emit RemoveTroll(trollProfileIndex);
        delete trollProfileInv[troll.troll];
        delete trollProfiles[trollProfileIndex];

        if (trollProfiles[trollProfileIndex].trollType == TrollType.SuperTroll) {
            superTrollCount--;
        } else if (trollProfiles[trollProfileIndex].trollType == TrollType.SuperTroll) {
            generalTrollCount--;
        }
    }

    function lockSuperTroll(uint256 trollProfileIndex) external {
        TrollProfile storage troll = trollProfiles[trollProfileIndex];
        require(troll.trollType == TrollType.SuperTroll, "not a super troll");
        require(isSuperTroll(msg.sender, false) || isPermitted[msg.sender], "not from super troll");
        // require(msg.sender != troll.troll, "cannot self lock");
        troll.trollType = TrollType.BlockedSuperTroll;
        emit LockSuperTroll(trollProfileIndex, msg.sender);
    }
    function unlockSuperTroll(bytes[] calldata signatures, uint256 trollProfileIndex, bool unlock, address[] calldata vaultRegistry, uint256[] calldata penalty, uint256 _nonce) external onlyOwner {
        signatures;
        _nonce;
        TrollProfile storage troll = trollProfiles[trollProfileIndex];
        require(troll.trollType == TrollType.BlockedSuperTroll, "not in locked status");
        uint256 length = vaultRegistry.length;
        require(length == penalty.length, "length not match");
        if (unlock)
            troll.trollType = TrollType.SuperTroll;

        for (uint256 i ; i < length ; i++) {
            OSWAP_BridgeVaultTrollRegistry(vaultRegistry[i]).penalizeSuperTroll(trollProfileIndex, penalty[i]);
            emit UnlockSuperTroll(trollProfileIndex, unlock, vaultRegistry[i], penalty[i]);
        }
    }
    function lockGeneralTroll(uint256 trollProfileIndex) external {
        TrollProfile storage troll = trollProfiles[trollProfileIndex];
        require(troll.trollType == TrollType.GeneralTroll, "not a general troll");
        require(isSuperTroll(msg.sender, false) || isPermitted[msg.sender], "not from super troll");
        troll.trollType = TrollType.BlockedGeneralTroll;
        emit LockGeneralTroll(trollProfileIndex, msg.sender);
    }
    function unlockGeneralTroll(bytes[] calldata signatures, uint256 trollProfileIndex, uint256 _nonce) external onlyOwner {
        signatures;
        _nonce;
        TrollProfile storage troll = trollProfiles[trollProfileIndex];
        require(troll.trollType == TrollType.BlockedGeneralTroll, "not in locked status");
        troll.trollType = TrollType.GeneralTroll;
        emit UnlockGeneralTroll(trollProfileIndex);
    }

    // Mock VotingManager
    event ParamSet(bytes32 indexed name, bytes32 value);
    event ParamSet2(bytes32 name, bytes32 value1, bytes32 value2);
    event UpgradeVotingManager(OSWAP_VotingManager newVotingManager);

    address[] public votingExecutor;
    mapping (address => uint256) public votingExecutorInv;
    mapping (address => bool) public isVotingExecutor;
    OSWAP_VotingManager public newVotingManager;

    function upgradeVotingManager(OSWAP_VotingManager _votingManager) external onlyVoting {
        _upgradeVotingManager(_votingManager);
    }
    function upgradeVotingManagerByAdmin(OSWAP_VotingManager _votingManager) external onlyOwner {
        _upgradeVotingManager(_votingManager);
    }
    function _upgradeVotingManager(OSWAP_VotingManager _votingManager) internal {
        // require(address(newVotingManager) == address(0), "already set");
        newVotingManager = _votingManager;
        emit UpgradeVotingManager(_votingManager);
    }
    function votingExecutorLength() external view returns (uint256) {
        return votingExecutor.length;
    }
    function setVotingExecutor(address _votingExecutor, bool _bool) external onlyVoting {
        _setVotingExecutor(_votingExecutor, _bool);
    }
    function _setVotingExecutor(address _votingExecutor, bool _bool) internal {
        require(_votingExecutor != address(0), "OSWAP: Invalid executor");

        if (votingExecutor.length==0 || votingExecutor[votingExecutorInv[_votingExecutor]] != _votingExecutor) {
            votingExecutorInv[_votingExecutor] = votingExecutor.length;
            votingExecutor.push(_votingExecutor);
        } else {
            require(votingExecutorInv[_votingExecutor] != 0, "OSWAP: cannot reset main executor");
        }
        isVotingExecutor[_votingExecutor] = _bool;
        emit ParamSet2("votingExecutor", bytes32(bytes20(_votingExecutor)), bytes32(uint256(_bool ? 1 : 0)));
    }
}