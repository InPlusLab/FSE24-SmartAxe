// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IAuthorization.sol";
import "./IOSWAP_BridgeVault.sol";
import "./IOSWAP_ConfigStore.sol";
import "./IOSWAP_VotingExecutorManager.sol";

interface IOSWAP_SideChainTrollRegistry is IAuthorization, IOSWAP_VotingExecutorManager {

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
    event UpdateConfigStore(IOSWAP_ConfigStore newConfigStore);
    event NewVault(IERC20 indexed token, IOSWAP_BridgeVault indexed vault);
    event SetVotingExecutor(address newVotingExecutor, bool isActive);
    event Upgrade(address newTrollRegistry);

    enum TrollType {NotSpecified, SuperTroll, GeneralTroll, BlockedSuperTroll, BlockedGeneralTroll}

    struct TrollProfile {
        address troll;
        TrollType trollType;
    }
    // function govToken() external view returns (IERC20 govToken);
    function configStore() external view returns (IOSWAP_ConfigStore configStore);
    // function votingExecutor(uint256 index) external view returns (address);
    // function votingExecutorInv(address) external view returns (uint256 votingExecutorInv);
    // function isVotingExecutor(address) external view returns (bool isVotingExecutor);
    function trollProfiles(uint256 trollProfileIndex) external view returns (TrollProfile memory trollProfiles); // trollProfiles[trollProfileIndex] = {troll, trollType}
    function trollProfileInv(address troll) external view returns (uint256 trollProfileInv); // trollProfileInv[troll] = trollProfileIndex
    function superTrollCount() external view returns (uint256 superTrollCount);
    function generalTrollCount() external view returns (uint256 generalTrollCount);
    function transactionsCount() external view returns (uint256 transactionsCount);
    function lastTrollTxCount(address troll) external view returns (uint256 lastTrollTxCount); // lastTrollTxCount[troll]
    function usedNonce(uint256) external view returns (bool usedNonce);

    function vaultToken(uint256 index) external view returns (IERC20);
    function vaults(IERC20) external view returns (IOSWAP_BridgeVault vaults); // vaultRegistries[token] = vault

    function newTrollRegistry() external view returns (address newTrollRegistry);

    function initAddress(address _votingExecutor, IERC20[] calldata tokens, IOSWAP_BridgeVault[] calldata _vaults) external;

    /*
     * upgrade
     */
    function updateConfigStore() external;
    function upgrade(address _trollRegistry) external;
    function upgradeByAdmin(address _trollRegistry) external;

    /*
     * pause / resume
     */
    function paused() external view returns (bool);
    function shutdownByAdmin() external;
    function shutdownByVoting() external;
    function resume() external;

    // function votingExecutorLength() external view returns (uint256);
    // function setVotingExecutor(address _votingExecutor, bool _bool) external;

    function vaultTokenLength() external view returns (uint256);
    function allVaultToken() external view returns (IERC20[] memory);

    function isSuperTroll(address troll, bool returnFalseIfBlocked) external view returns (bool);
    function isSuperTrollByIndex(uint256 trollProfileIndex, bool returnFalseIfBlocked) external view returns (bool);
    function isGeneralTroll(address troll, bool returnFalseIfBlocked) external view returns (bool);
    function isGeneralTrollByIndex(uint256 trollProfileIndex, bool returnFalseIfBlocked) external view returns (bool);

    function verifySignatures(address msgSender, bytes[] calldata signatures, bytes32 paramsHash, uint256 _nonce) external;
    function hashAddTroll(uint256 trollProfileIndex, address troll, bool _isSuperTroll, uint256 _nonce) external view returns (bytes32);
    function hashUpdateTroll(uint256 trollProfileIndex, address newTroll, uint256 _nonce) external view returns (bytes32);
    function hashRemoveTroll(uint256 trollProfileIndex, uint256 _nonce) external view returns (bytes32);
    function hashUnlockTroll(uint256 trollProfileIndex, bool unlock, address[] memory vaultRegistry, uint256[] memory penalty, uint256 _nonce) external view returns (bytes32);
    function hashRegisterVault(IERC20 token, IOSWAP_BridgeVault vaultRegistry, uint256 _nonce) external view returns (bytes32);

    function addTroll(bytes[] calldata signatures, uint256 trollProfileIndex, address troll, bool _isSuperTroll, uint256 _nonce) external;
    function updateTroll(bytes[] calldata signatures, uint256 trollProfileIndex, address newTroll, uint256 _nonce) external;
    function removeTroll(bytes[] calldata signatures, uint256 trollProfileIndex, uint256 _nonce) external;

    function lockSuperTroll(uint256 trollProfileIndex) external;
    function unlockSuperTroll(bytes[] calldata signatures, uint256 trollProfileIndex, bool unlock, address[] calldata vaultRegistry, uint256[] calldata penalty, uint256 _nonce) external;
    function lockGeneralTroll(uint256 trollProfileIndex) external;
    function unlockGeneralTroll(bytes[] calldata signatures, uint256 trollProfileIndex, uint256 _nonce) external;

    function registerVault(bytes[] calldata signatures, IERC20 token, IOSWAP_BridgeVault vault, uint256 _nonce) external;
}
