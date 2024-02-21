// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IOSWAP_VotingExecutorManager.sol";
import "./OSWAP_ConfigStore.sol";

contract OSWAP_ChainRegistry {

    modifier onlyVoting() {
        require(votingExecutorManager.isVotingExecutor(msg.sender), "OSWAP: Not from voting");
        _;
    }
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

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
    event UpdateConfigStore(uint256 indexed chainId, OSWAP_ConfigStore _address);
    event UpdateVault(uint256 indexed index, uint256 indexed chainId, Vault vault);

    address owner;

    IOSWAP_VotingExecutorManager public votingExecutorManager;

    uint256[] public chains; // chains[idx] = chainId
    mapping(uint256 => Status) public status; // status[chainId] = {NotExists, Active, Inactive}
    mapping(bytes32 => address) public mainChainContractAddress; // mainChainContractAddress[contractName] = contractAddress
    mapping(uint256 => mapping(bytes32 => address)) public sideChainContractAddress; //sideChainContractAddress[chainId][contractName] = contractAddress
    mapping(uint256 => IERC20) public govToken; // govToken[chainId] = govToken
    // the source-of-truth configStore of a sidechain on mainchain
    // the configStore on a sidechain should be a replica of this
    mapping(uint256 => OSWAP_ConfigStore) public configStore; // configStore[chainId]

    bytes32[] public tokenNames;
    mapping(uint256 => Vault)[] public vaults; // vaults[tokensIdx][chainId] = {token, vaultRegistry, bridgeVault}

    constructor(IOSWAP_VotingExecutorManager _votingExecutorManager) {
        votingExecutorManager = _votingExecutorManager;
        owner = msg.sender;
    }

    function init(
        uint256[] memory chainId, 
        Status[] memory _status, 
        IERC20[] memory _govToken, 
        OSWAP_ConfigStore[] memory _configStore,  
        bytes32[] memory mainChainContractNames, 
        address[] memory _mainChainContractAddress, 
        bytes32[] memory contractNames, 
        address[][] memory _address,
        bytes32[] memory _tokenNames,
        Vault[][] memory vault
    ) external onlyOwner {
        require(chains.length == 0, "already init");
        require(chainId.length != 0, "invalid length");
        // uint256 length = chainId.length;
        require(chainId.length==_status.length && chainId.length==_govToken.length && chainId.length==_configStore.length && chainId.length==_address.length, "array length not matched");
        require(mainChainContractNames.length == _mainChainContractAddress.length, "array length not matched");

        for (uint256 i ; i < mainChainContractNames.length ; i++) {
            _updateMainChainAddress(mainChainContractNames[i], _mainChainContractAddress[i]);
        }

        for (uint256 i ; i < chainId.length ; i++) {
            _addChain(chainId[i], _status[i], _govToken[i], _configStore[i], contractNames, _address[i]);
        }
        
        // length = _tokenNames.length;
        require(_tokenNames.length == vault.length, "array length not matched");
        for (uint256 i ; i < _tokenNames.length ; i++) {
            _newVault(_tokenNames[i], chainId, vault[i]);
        }
        owner = address(0);
    }
    function chainsLength() external view returns (uint256) {
        return chains.length;
    }
    function allChains() external view returns (uint256[] memory) {
        return chains;
    }
    function tokenNamesLength() external view returns (uint256) {
        return tokenNames.length;
    }
    function vaultsLength() external view returns (uint256) {
        return vaults.length;
    }

    function getChain(uint256 chainId, bytes32[] calldata contractnames) external view returns (Status _status, IERC20 _govToken, OSWAP_ConfigStore _configStore, address[] memory _contracts, Vault[] memory _vaults) {
        _status = status[chainId];
        _govToken = govToken[chainId];
        _configStore = configStore[chainId];
        uint256 length = contractnames.length;
        _contracts = new address[](length);
        for (uint256 i ; i < length ; i++) {
            _contracts[i] = sideChainContractAddress[chainId][contractnames[i]];
        }
        length = vaults.length;
        _vaults = new Vault[](length);
        for (uint256 i ; i < length ; i++) {
            _vaults[i] = vaults[i][chainId];
        }
    }
    function addChain(uint256 chainId, Status _status, IERC20 _govToken, OSWAP_ConfigStore _configStore,  bytes32[] memory contractNames, address[] memory _address) external onlyVoting {
        _addChain(chainId, _status, _govToken, _configStore, contractNames, _address);
    }
    function _addChain(uint256 chainId, Status _status, IERC20 _govToken, OSWAP_ConfigStore _configStore,  bytes32[] memory contractNames, address[] memory _address) internal {
        require(status[chainId] == Status.NotExists, "chain already exists");
        require(_status > Status.NotExists, "invalid status");
        require(contractNames.length == _address.length, "array length not matched");
        
        chains.push(chainId);
        status[chainId] = _status;
        govToken[chainId] = _govToken;
        emit NewChain(chainId, _status, _govToken);

        configStore[chainId] = _configStore;
        emit UpdateConfigStore(chainId, _configStore);

        uint256 length = contractNames.length;
        for (uint256 i ; i < length ; i++) {
            sideChainContractAddress[chainId][contractNames[i]] = _address[i];
            emit UpdateAddress(chainId, contractNames[i], _address[i]);
        }
    }
    function updateStatus(uint256 chainId, Status _status) external onlyVoting {
        require(status[chainId] != Status.NotExists, "chain not exists");
        require(_status == Status.Active || _status == Status.Inactive, "invalid status");
        status[chainId] = _status;
        emit UpdateStatus(chainId, _status);
    }
    function _updateMainChainAddress(bytes32 contractName, address _address) internal {
        mainChainContractAddress[contractName] = _address;
        emit UpdateMainChainAddress(contractName, _address);
    }
    function updateMainChainAddress(bytes32 contractName, address _address) external onlyVoting {
        _updateMainChainAddress(contractName, _address);
    }
    function updateAddress(uint256 chainId, bytes32 contractName, address _address) external onlyVoting {
        require(status[chainId] != Status.NotExists, "chain not exists");
        sideChainContractAddress[chainId][contractName] = _address;
        emit UpdateAddress(chainId, contractName, _address);
    }
    function updateAddresses(uint256 chainId, bytes32[] memory contractNames, address[] memory _addresses) external onlyVoting {
        require(status[chainId] != Status.NotExists, "chain not exists");
        uint256 length = contractNames.length;
        require(length == _addresses.length, "array length not matched");
        for (uint256 i ; i < length ; i++) {
            sideChainContractAddress[chainId][contractNames[i]] = _addresses[i];
            emit UpdateAddress(chainId, contractNames[i], _addresses[i]);
        }
    }
    function updateConfigStore(uint256 chainId, OSWAP_ConfigStore _address) external onlyVoting {
        require(status[chainId] != Status.NotExists, "chain not exists");
        configStore[chainId] = _address;
        emit UpdateConfigStore(chainId,  _address);
    }
    function newVault(bytes32 name, uint256[] memory chainId, Vault[] memory vault) external onlyVoting returns (uint256 index) {
        return _newVault(name, chainId, vault);
    }
    function _newVault(bytes32 name, uint256[] memory chainId, Vault[] memory vault) internal returns (uint256 index) {
        uint256 length = chainId.length;
        require(length == vault.length, "array length not matched");
        index = vaults.length;
        tokenNames.push(name);
        vaults.push();
        for (uint256 i ; i < length ; i++) {
            require(status[chainId[i]] != Status.NotExists, "chain not exists");
            vaults[index][chainId[i]] = vault[i];
            emit UpdateVault(index, chainId[i], vault[i]);
        }
    }
    function updateVault(uint256 index, uint256 chainId, Vault memory vault) external onlyVoting {
        require(index < vaults.length, "invalid index");
        require(status[chainId] != Status.NotExists, "chain not exists");
        vaults[index][chainId] = vault;
        emit UpdateVault(index, chainId, vault);
    }
}
