// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./Authorization.sol";
import "./interfaces/IOSWAP_BridgeVault.sol";
import "./OSWAP_BridgeVaultTrollRegistry.sol";
import "./OSWAP_ConfigStore.sol";

contract OSWAP_SideChainTrollRegistry is Authorization {
    using ECDSA for bytes32;

    modifier onlyVoting() {
        require(isVotingExecutor[msg.sender], "OSWAP: Not from voting");
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
    event UpdateTroll(uint256 indexed trollProfileIndex, address indexed troll);
    event RemoveTroll(uint256 indexed trollProfileIndex);
    event DelistTroll(uint256 indexed trollProfileIndex);
    event LockSuperTroll(uint256 indexed trollProfileIndex, address lockedBy);
    event LockGeneralTroll(uint256 indexed trollProfileIndex, address lockedBy);
    event UnlockSuperTroll(uint256 indexed trollProfileIndex, bool unlock, address bridgeVault, uint256 penalty);
    event UnlockGeneralTroll(uint256 indexed trollProfileIndex);
    event UpdateConfigStore(OSWAP_ConfigStore newConfigStore);
    event NewVault(IERC20 indexed token, IOSWAP_BridgeVault indexed vault);
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

    // votingManager
    address[] public votingExecutor;
    mapping (address => uint256) public votingExecutorInv;
    mapping (address => bool) public isVotingExecutor;
    address public immutable trollRegistry = address(this);

    mapping(uint256 => TrollProfile) public trollProfiles; // trollProfiles[trollProfileIndex] = {troll, trollType}
    mapping(address => uint256) public trollProfileInv; // trollProfileInv[troll] = trollProfileIndex

    uint256 public superTrollCount;
    uint256 public generalTrollCount;

    uint256 public transactionsCount;
    mapping(address => uint256) public lastTrollTxCount; // lastTrollTxCount[troll]
    mapping(uint256 => bool) public usedNonce;

    IERC20[] public vaultToken;
    mapping(IERC20 => IOSWAP_BridgeVault) public vaults; // vaultRegistries[token] = vault

    address public newTrollRegistry;
    function newVotingExecutorManager() external view returns (address) { return newTrollRegistry; }

    constructor(OSWAP_ConfigStore _configStore) {
        configStore = _configStore;
        govToken = _configStore.govToken();
        isPermitted[msg.sender] = true;
    }
    function initAddress(address _votingExecutor, IERC20[] calldata tokens, IOSWAP_BridgeVault[] calldata _vaults) external onlyOwner {
        require(address(_votingExecutor) != address(0), "null address");
        _setVotingExecutor(_votingExecutor, true);

        uint256 length = tokens.length;
        require(length == _vaults.length, "array length not matched");
        for (uint256 i ; i < length ; i++) {
            vaultToken.push(tokens[i]);
            vaults[tokens[i]] = _vaults[i];
            emit NewVault(tokens[i], _vaults[i]);
        }

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

    function upgrade(address _trollRegistry) external onlyVoting {
        _upgrade(_trollRegistry);
    }
    function upgradeByAdmin(address _trollRegistry) external onlyOwner {
        _upgrade(_trollRegistry);
    }
    function _upgrade(address _trollRegistry) internal {
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
        emit SetVotingExecutor(_votingExecutor, _bool);
    }

    function vaultTokenLength() external view returns (uint256) {
        return vaultToken.length;
    }
    function allVaultToken() external view returns (IERC20[] memory) {
        return vaultToken;
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

    function verifySignatures(address msgSender, bytes[] calldata signatures, bytes32 paramsHash, uint256 _nonce) external onlyVoting {
        _verifySignatures(msgSender, signatures, paramsHash, _nonce);
    }
    function _verifySignatures(address msgSender, bytes[] calldata signatures, bytes32 paramsHash, uint256 _nonce) internal {
        require(isSuperTroll(msgSender, false) || isPermitted[msgSender], "not from super troll");
        require(!usedNonce[_nonce], "nonce used");
        usedNonce[_nonce] = true;
        uint256 _superTrollCount;
        bool adminSigned;
        address lastSigningTroll;
        for (uint i = 0; i < signatures.length; ++i) {
            address troll = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", paramsHash)).recover(signatures[i]);
            require(troll != address(0), "Invalid signer");
            if (isSuperTroll(troll, false)) {
                if (troll > lastSigningTroll) {
                    _superTrollCount++;
                    lastSigningTroll = troll;
                }
            } else if (isPermitted[troll]) {
                adminSigned = true;
            }
        }

        uint256 transactionsGap = configStore.transactionsGap();

        // fuzzy round robin
        uint256 _transactionsCount = (++transactionsCount);
        if (!adminSigned)
            require((lastTrollTxCount[msgSender] + transactionsGap < _transactionsCount) || (_transactionsCount <= transactionsGap), "too soon");
        lastTrollTxCount[msgSender] = _transactionsCount;

        require(
            (superTrollCount > 0 && _superTrollCount == superTrollCount) || 
            ((_superTrollCount > (superTrollCount+1)/2 && adminSigned) || 
            (superTrollCount == 0 && adminSigned))
        , "OSWAP_TrollRegistry: SuperTroll count not met");
    }
    function hashAddTroll(uint256 trollProfileIndex, address troll, bool _isSuperTroll, uint256 _nonce) public view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return keccak256(abi.encodePacked(
            chainId,
            address(this),
            trollProfileIndex,
            troll,
            _isSuperTroll,
            _nonce
        ));
    }
    function hashUpdateTroll(uint256 trollProfileIndex, address newTroll, uint256 _nonce) public view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return keccak256(abi.encodePacked(
            chainId,
            address(this),
            trollProfileIndex,
            newTroll,
            _nonce
        ));
    }
    function hashRemoveTroll(uint256 trollProfileIndex, uint256 _nonce) public view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return keccak256(abi.encodePacked(
            chainId,
            address(this),
            trollProfileIndex,
            _nonce
        ));
    }
    function hashUnlockTroll(uint256 trollProfileIndex, bool unlock, address[] memory vaultRegistry, uint256[] memory penalty, uint256 _nonce) public view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return keccak256(abi.encodePacked(
            chainId,
            address(this),
            trollProfileIndex,
            unlock,
            vaultRegistry,
            penalty,
            _nonce
        ));
    }
    function hashRegisterVault(IERC20 token, IOSWAP_BridgeVault vault, uint256 _nonce) public view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return keccak256(abi.encodePacked(
            chainId,
            address(this),
            token,
            vault,
            _nonce
        ));
    }

    function addTroll(bytes[] calldata signatures, uint256 trollProfileIndex, address troll, bool _isSuperTroll, uint256 _nonce) external {
        bytes32 hash = hashAddTroll(trollProfileIndex, troll, _isSuperTroll, _nonce);
        _verifySignatures(msg.sender, signatures, hash, _nonce);
        require(troll != address(0), "Invalid troll");
        require(trollProfileIndex != 0, "trollProfileIndex cannot be zero");
        require(trollProfiles[trollProfileIndex].trollType == TrollType.NotSpecified, "already added");
        require(trollProfileInv[troll] == 0, "already added");
        trollProfiles[trollProfileIndex] = TrollProfile({troll:troll, trollType:_isSuperTroll ? TrollType.SuperTroll : TrollType.GeneralTroll});
        trollProfileInv[troll] = trollProfileIndex;
        if (trollProfiles[trollProfileIndex].trollType == TrollType.SuperTroll) {
            superTrollCount++;
        } else if (trollProfiles[trollProfileIndex].trollType == TrollType.GeneralTroll) {
            generalTrollCount++;
        } else {
            revert("invalid troll type");
        }
        emit AddTroll(troll, trollProfileIndex, _isSuperTroll);
    }
    function updateTroll(bytes[] calldata signatures, uint256 trollProfileIndex, address newTroll, uint256 _nonce) external {
        bytes32 hash = hashUpdateTroll(trollProfileIndex, newTroll, _nonce);
        _verifySignatures(msg.sender, signatures, hash, _nonce);
        require(newTroll != address(0), "Invalid troll");
        require(trollProfileInv[newTroll] == 0, "newTroll already exists");
        TrollProfile storage troll = trollProfiles[trollProfileIndex];
        require(troll.trollType != TrollType.NotSpecified, "not a valid troll");
        delete trollProfileInv[troll.troll];
        trollProfiles[trollProfileIndex].troll = newTroll;
        trollProfileInv[newTroll] = trollProfileIndex;
        emit UpdateTroll(trollProfileIndex, newTroll);
    }
    function removeTroll(bytes[] calldata signatures, uint256 trollProfileIndex, uint256 _nonce) external {
        bytes32 hash = hashRemoveTroll(trollProfileIndex, _nonce);
        _verifySignatures(msg.sender, signatures, hash, _nonce);
        TrollProfile storage troll = trollProfiles[trollProfileIndex];
        require(troll.trollType != TrollType.NotSpecified, "not a valid troll");
        emit RemoveTroll(trollProfileIndex);

        TrollType trollType = trollProfiles[trollProfileIndex].trollType;
        if (trollType == TrollType.SuperTroll || trollType == TrollType.BlockedSuperTroll) {
            superTrollCount--;
        } else if (trollType == TrollType.GeneralTroll || trollType == TrollType.BlockedGeneralTroll) {
            generalTrollCount--;
        } else {
            revert("invalid troll type");
        }
        delete trollProfileInv[troll.troll];
        delete trollProfiles[trollProfileIndex];
    }

    function lockSuperTroll(uint256 trollProfileIndex) external {
        require(isSuperTroll(msg.sender, false) || isPermitted[msg.sender], "not from super troll");
        TrollProfile storage troll = trollProfiles[trollProfileIndex];
        require(troll.trollType == TrollType.SuperTroll, "not a super troll");
        // require(msg.sender != troll.troll, "cannot self lock");
        troll.trollType = TrollType.BlockedSuperTroll;
        emit LockSuperTroll(trollProfileIndex, msg.sender);
    }
    function unlockSuperTroll(bytes[] calldata signatures, uint256 trollProfileIndex, bool unlock, address[] calldata vaultRegistry, uint256[] calldata penalty, uint256 _nonce) external {
        bytes32 hash = hashUnlockTroll(trollProfileIndex, unlock, vaultRegistry, penalty, _nonce);
        _verifySignatures(msg.sender, signatures, hash, _nonce);
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
        require(isSuperTroll(msg.sender, false) || isPermitted[msg.sender], "not from super troll");
        TrollProfile storage troll = trollProfiles[trollProfileIndex];
        require(troll.trollType == TrollType.GeneralTroll, "not a general troll");
        troll.trollType = TrollType.BlockedGeneralTroll;
        emit LockGeneralTroll(trollProfileIndex, msg.sender);
    }
    function unlockGeneralTroll(bytes[] calldata signatures, uint256 trollProfileIndex, uint256 _nonce) external {
        bytes32 hash = hashUnlockTroll(trollProfileIndex, true, new address[](0), new uint256[](0), _nonce);
        _verifySignatures(msg.sender, signatures, hash, _nonce);
        TrollProfile storage troll = trollProfiles[trollProfileIndex];
        require(troll.trollType == TrollType.BlockedGeneralTroll, "not in locked status");
        troll.trollType = TrollType.GeneralTroll;
        emit UnlockGeneralTroll(trollProfileIndex);
    }

    function registerVault(bytes[] calldata signatures, IERC20 token, IOSWAP_BridgeVault vault, uint256 _nonce) external {
        bytes32 hash = hashRegisterVault(token, vault, _nonce);
        _verifySignatures(msg.sender, signatures, hash, _nonce);
        vaultToken.push(token);
        vaults[token] = vault;
        emit NewVault(token, vault);
    }
}
