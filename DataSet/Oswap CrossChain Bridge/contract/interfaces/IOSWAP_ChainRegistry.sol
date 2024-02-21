// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IOSWAP_ConfigStore.sol";
import "./IOSWAP_VotingExecutorManager.sol";

interface IOSWAP_ChainRegistry {

    enum Status {NotExists, Active, Inactive}

    struct Vault {
        address token;
        address vaultRegistry; // OSWAP_BridgeVaultTrollRegistry
        address bridgeVault; // OSWAP_BridgeVault
    }

    event NewChain(uint256 indexed chainId, Status status, IERC20 govToken);
    event UpdateStatus(uint256 indexed chainId, Status status);
    event UpdateMainChainAddress(bytes32 indexed contractName, address _address);
    event UpdateAddress(uint256 indexed chainId, bytes32 indexed contractName, address _address);
    event UpdateConfigStore(uint256 indexed chainId, IOSWAP_ConfigStore _address);
    event UpdateVault(uint256 indexed index, uint256 indexed chainId, Vault vault);

    function votingExecutorManager() external view returns (IOSWAP_VotingExecutorManager votingExecutorManager);
    function chains(uint256 index) external view returns (uint256); // chains[idx] = chainId
    function status(uint256) external view returns (Status status); // status[chainId] = {NotExists, Active, Inactive}
    function mainChainContractAddress(bytes32) external view returns (address mainChainContractAddress); // mainChainContractAddress[contractName] = contractAddress
    // OSWAP_SideChainTrollRegistry, OSWAP_SideChainVotingExecutor, OSWAP_RouterVaultWrapper, OSWAP_ConfigStore
    function sideChainContractAddress(uint256, bytes32) external view returns (address sideChainContractAddress); //sideChainContractAddress[chainId][contractName] = contractAddress
    function govToken(uint256) external view returns (IERC20 govToken); // govToken[chainId] = govToken
    // the source-of-truth configStore of a sidechain on mainchain
    // the configStore on a sidechain should be a replica of this
    function configStore(uint256) external view returns (IOSWAP_ConfigStore configStore); // configStore[chainId]
    function tokenNames(uint256 index) external view returns (bytes32);
    function vaults(uint256, uint256) external view returns (Vault memory vaults); // vaults[tokensIdx][chainId] = {token, vaultRegistry, bridgeVault}

    function init(
        uint256[] memory chainId, 
        Status[] memory _status, 
        IERC20[] memory _govToken, 
        IOSWAP_ConfigStore[] memory _configStore,  
        bytes32[] memory mainChainContractNames, 
        address[] memory _mainChainContractAddress, 
        bytes32[] memory contractNames, 
        address[][] memory _address,
        bytes32[] memory _tokenNames,
        Vault[][] memory vault
    ) external;
    function chainsLength() external view returns (uint256);
    function allChains() external view returns (uint256[] memory);
    function tokenNamesLength() external view returns (uint256);
    function vaultsLength() external view returns (uint256);

    function getChain(uint256 chainId, bytes32[] calldata contractnames) external view returns (Status _status, IERC20 _govToken, IOSWAP_ConfigStore _configStore, address[] memory _contracts, Vault[] memory _vaults);

    function addChain(uint256 chainId, Status _status, IERC20 _govToken, IOSWAP_ConfigStore _configStore,  bytes32[] memory contractNames, address[] memory _address) external;
    function updateStatus(uint256 chainId, Status _status) external;
    function updateMainChainAddress(bytes32 contractName, address _address) external;
    function updateAddress(uint256 chainId, bytes32 contractName, address _address) external;
    function updateAddresses(uint256 chainId, bytes32[] memory contractNames, address[] memory _addresses) external;
    function updateConfigStore(uint256 chainId, IOSWAP_ConfigStore _address) external;
    function newVault(bytes32 name, uint256[] memory chainId, Vault[] memory vault) external returns (uint256 index);
    function updateVault(uint256 index, uint256 chainId, Vault memory vault) external;
}
