// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IOSWAP_BridgeVault.sol";
import "./OSWAP_ConfigStore.sol";
import "./OSWAP_SideChainTrollRegistry.sol";

contract OSWAP_BridgeVaultTrollRegistry is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;


    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    modifier whenNotPaused() {
        require(!trollRegistry.paused(), "PAUSED!");
        _;
    }

    event Stake(address indexed backer, uint256 indexed trollProfileIndex, uint256 amount, uint256 shares, uint256 backerBalance, uint256 trollBalance, uint256 totalShares);
    event UnstakeRequest(address indexed backer, uint256 indexed trollProfileIndex, uint256 shares, uint256 backerBalance);
    event Unstake(address indexed backer, uint256 indexed trollProfileIndex, uint256 amount, uint256 shares, uint256 approvalDecrement, uint256 trollBalance, uint256 totalShares);
    event UnstakeApproval(address indexed backer, address indexed msgSender, uint256[] signers, uint256 shares);
    event UpdateConfigStore(OSWAP_ConfigStore newConfigStore);
    event UpdateTrollRegistry(OSWAP_SideChainTrollRegistry newTrollRegistry);
    event Penalty(uint256 indexed trollProfileIndex, uint256 amount);

    struct Stakes{
        uint256 trollProfileIndex;
        uint256 shares;
        uint256 pendingWithdrawal;
        uint256 approvedWithdrawal;
    }
    // struct StakedBy{
    //     address backer;
    //     uint256 index;
    // }

    address owner;
    IERC20 public immutable govToken;
    OSWAP_ConfigStore public configStore;
    OSWAP_SideChainTrollRegistry public trollRegistry;
    IOSWAP_BridgeVault public bridgeVault;

    mapping(address => Stakes) public backerStakes; // backerStakes[bakcer] = Stakes;
    mapping(uint256 => address[]) public stakedBy; // stakedBy[trollProfileIndex][idx] = backer;
    mapping(uint256 => mapping(address => uint256)) public stakedByInv; // stakedByInv[trollProfileIndex][backer] = stakedBy_idx;

    mapping(uint256 => uint256) public trollStakesBalances; // trollStakesBalances[trollProfileIndex] = balance
    mapping(uint256 => uint256) public trollStakesTotalShares; // trollStakesTotalShares[trollProfileIndex] = shares


    uint256 public transactionsCount;
    mapping(address => uint256) public lastTrollTxCount; // lastTrollTxCount[troll]
    mapping(bytes32 => bool) public usedNonce;

    constructor(OSWAP_SideChainTrollRegistry _trollRegistry) {
        trollRegistry = _trollRegistry;
        configStore = _trollRegistry.configStore();
        govToken = _trollRegistry.govToken();
        owner = msg.sender;
    }
    function initAddress(IOSWAP_BridgeVault _bridgeVault) external onlyOwner {
        require(address(bridgeVault) == address(0), "address already set");
        bridgeVault = _bridgeVault;
    }
    function updateConfigStore() external {
        OSWAP_ConfigStore _configStore = configStore.newConfigStore();
        require(address(_configStore) != address(0), "Invalid config store");
        configStore = _configStore;
        emit UpdateConfigStore(configStore);
    }
    function updateTrollRegistry() external {
        OSWAP_SideChainTrollRegistry _trollRegistry = OSWAP_SideChainTrollRegistry(trollRegistry.newTrollRegistry());
        require(address(_trollRegistry) != address(0), "Invalid config store");
        trollRegistry = _trollRegistry;
        emit UpdateTrollRegistry(trollRegistry);
    }

    function stakedByLength(uint256 trollProfileIndex) external view returns (uint256 length) {
        length = stakedBy[trollProfileIndex].length;
    }
    function getBackers(uint256 trollProfileIndex) external view returns (address[] memory backers) {
        return stakedBy[trollProfileIndex];
    }

    function removeStakedBy(uint256 _index) internal {
        uint idx = stakedByInv[_index][msg.sender];
        uint256 lastIdx = stakedBy[_index].length - 1;
        if (idx != lastIdx){
            stakedBy[_index][idx] = stakedBy[_index][lastIdx];
            stakedByInv[_index][ stakedBy[_index][idx] ] = idx;
        }
        stakedBy[_index].pop();
        delete stakedByInv[_index][msg.sender];
    }

    function stake(uint256 trollProfileIndex, uint256 amount) external nonReentrant whenNotPaused returns (uint256 shares){
        (,OSWAP_SideChainTrollRegistry.TrollType trollType) = trollRegistry.trollProfiles(trollProfileIndex);
        // OSWAP_SideChainTrollRegistry.TrollProfile memory profile = trollRegistry.trollProfiles(trollProfileIndex);
        require(trollType == OSWAP_SideChainTrollRegistry.TrollType.SuperTroll, "Not a Super Troll");

        if (amount > 0) {
            uint256 balance = govToken.balanceOf(address(this));
            govToken.safeTransferFrom(msg.sender, address(this), amount);
            amount = govToken.balanceOf(address(this)) - balance;
        }

        Stakes storage staking = backerStakes[msg.sender];
        if (staking.shares > 0) {
            if (staking.trollProfileIndex != trollProfileIndex) {
                require(staking.pendingWithdrawal == 0 && staking.approvedWithdrawal == 0, "you have pending withdrawal");
                // existing staking found, remvoe stakes from old troll and found the latest stakes amount after penalties
                uint256 _index = staking.trollProfileIndex;
                uint256 stakedAmount = staking.shares * trollStakesBalances[_index] / trollStakesTotalShares[_index];
                trollStakesBalances[_index] -= stakedAmount;
                trollStakesTotalShares[_index] -= staking.shares;
                amount += stakedAmount;

                removeStakedBy(_index);

                emit UnstakeRequest(msg.sender, _index, staking.shares, 0);
                emit Unstake(msg.sender, _index, stakedAmount, staking.shares, 0, trollStakesBalances[_index], trollStakesTotalShares[_index]);

                stakedByInv[trollProfileIndex][msg.sender] = stakedBy[trollProfileIndex].length;
                stakedBy[trollProfileIndex].push(msg.sender);

                staking.trollProfileIndex = trollProfileIndex;
                staking.shares = 0;
            }
        } else {
            // new staking
            staking.trollProfileIndex = trollProfileIndex;
            stakedByInv[trollProfileIndex][msg.sender] = stakedBy[trollProfileIndex].length;
            stakedBy[trollProfileIndex].push(msg.sender);
        }

        uint256 trollActualBalance = trollStakesBalances[trollProfileIndex];
        shares = trollActualBalance == 0 ? amount : (amount * trollStakesTotalShares[trollProfileIndex] / trollActualBalance);
        require(shares > 0, "amount too small");
        trollStakesTotalShares[trollProfileIndex] += shares;
        trollStakesBalances[trollProfileIndex] += amount;
        staking.shares += shares;

        emit Stake(msg.sender, trollProfileIndex, amount, shares, staking.shares, trollStakesBalances[trollProfileIndex], trollStakesTotalShares[trollProfileIndex]);

    }
    function maxWithdrawal(address backer) external view returns (uint256 amount) {
        Stakes storage staking = backerStakes[backer];
        uint256 trollProfileIndex = staking.trollProfileIndex;
        amount = staking.shares * (trollStakesBalances[trollProfileIndex]) / trollStakesTotalShares[trollProfileIndex];
    }

    function hashUnstakeRequest(address backer, uint256 trollProfileIndex, uint256 shares, uint256 _nonce) public view returns (bytes32 hash) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return keccak256(abi.encodePacked(
            chainId,
            address(this),
            backer,
            trollProfileIndex,
            shares,
            _nonce
        ));
    }
    function unstakeRequest(uint256 shares) external whenNotPaused {
        Stakes storage staking = backerStakes[msg.sender];
        uint256 trollProfileIndex = staking.trollProfileIndex;
        require(trollProfileIndex != 0, "not a backer");
        staking.shares -= shares;
        staking.pendingWithdrawal += shares;

        if (staking.shares == 0){
            removeStakedBy(trollProfileIndex);
        }

        emit UnstakeRequest(msg.sender, trollProfileIndex, shares, staking.shares);
    }
    function unstakeApprove(bytes[] calldata signatures, address backer, uint256 trollProfileIndex, uint256 shares, uint256 _nonce) external {
        Stakes storage staking = backerStakes[backer];
        require(trollProfileIndex == staking.trollProfileIndex, "invalid trollProfileIndex");
        require(shares <= staking.pendingWithdrawal, "Invalid shares amount");
        (,, uint256[] memory signers) = _verifyStakedValue(msg.sender, signatures, hashUnstakeRequest(backer, trollProfileIndex, shares, _nonce));
        staking.approvedWithdrawal += shares;
        emit UnstakeApproval(backer, msg.sender, signers, shares);
    }
    function unstake(address backer, uint256 shares) external nonReentrant whenNotPaused {
        Stakes storage staking = backerStakes[backer];
        require(shares <= staking.approvedWithdrawal, "amount exceeded approval");
        uint256 trollProfileIndex = staking.trollProfileIndex;

        staking.approvedWithdrawal -= shares;
        staking.pendingWithdrawal -= shares;

        uint256 amount = shares * trollStakesBalances[trollProfileIndex] / trollStakesTotalShares[trollProfileIndex];

        trollStakesTotalShares[trollProfileIndex] -= shares;
        trollStakesBalances[trollProfileIndex] -= amount;

        govToken.safeTransfer(backer, amount);

        emit Unstake(backer, trollProfileIndex, amount, shares, shares, trollStakesBalances[trollProfileIndex], trollStakesTotalShares[trollProfileIndex]);
    }

    function verifyStakedValue(address msgSender, bytes[] calldata signatures, bytes32 paramsHash) external returns (uint256 superTrollCount, uint totalStake, uint256[] memory signers) {
        require(msg.sender == address(bridgeVault), "not authorized");
        return _verifyStakedValue(msgSender, signatures, paramsHash);
    }
    function _verifyStakedValue(address msgSender, bytes[] calldata signatures, bytes32 paramsHash) internal returns (uint256 superTrollCount, uint totalStake, uint256[] memory signers) {
        require(!usedNonce[paramsHash], "nonce used");
        usedNonce[paramsHash] = true;

        uint256 generalTrollCount;
        {
        uint256 length = signatures.length;
        signers = new uint256[](length);
        address lastSigningTroll;
        for (uint256 i = 0; i < length; ++i) {
            address troll = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", paramsHash)).recover(signatures[i]);
            require(troll != address(0), "Invalid signer");
            uint256 trollProfileIndex = trollRegistry.trollProfileInv(troll);
            if (trollProfileIndex > 0 && troll > lastSigningTroll) {
                signers[i] = trollProfileIndex;
                if (trollRegistry.isSuperTroll(troll, true)) {
                    superTrollCount++;
                } else if (trollRegistry.isGeneralTroll(troll, true)) {
                    generalTrollCount++;
                }
                totalStake += trollStakesBalances[trollProfileIndex];
                lastSigningTroll = troll;
            }
        }
        }

        (uint256 generalTrollMinCount, uint256 superTrollMinCount, uint256 transactionsGap) = configStore.getSignatureVerificationParams();
        require(generalTrollCount >= generalTrollMinCount, "OSWAP_BridgeVault: Mininum general troll count not met");
        require(superTrollCount >= superTrollMinCount, "OSWAP_BridgeVault: Mininum super troll count not met");

        // fuzzy round robin
        uint256 _transactionsCount = (++transactionsCount);
        require((lastTrollTxCount[msgSender] + transactionsGap < _transactionsCount) || (_transactionsCount <= transactionsGap), "too soon");
        lastTrollTxCount[msgSender] = _transactionsCount;
    }

    function penalizeSuperTroll(uint256 trollProfileIndex, uint256 amount) external {
        require(msg.sender == address(trollRegistry), "not from registry");
        require(amount <= trollStakesBalances[trollProfileIndex], "penalty exceeds troll balance");
        trollStakesBalances[trollProfileIndex] -= amount;
        // if penalty == balance, forfeit all backers' bonds
        if (trollStakesBalances[trollProfileIndex] == 0) {
            delete trollStakesBalances[trollProfileIndex];
            delete trollStakesTotalShares[trollProfileIndex];
            address[] storage backers = stakedBy[trollProfileIndex];
            uint256 length = backers.length;
            for (uint256 i = 0 ; i < length ; i++) {
                address backer = backers[i];
                delete backerStakes[backer];
                delete stakedByInv[trollProfileIndex][backer];
            }
            delete stakedBy[trollProfileIndex];
        }
        emit Penalty(trollProfileIndex, amount);
    }
}