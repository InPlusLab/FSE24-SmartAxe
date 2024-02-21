// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IOSWAP_ConfigStore.sol";
import "./IOSWAP_SideChainTrollRegistry.sol";

interface IOSWAP_BridgeVaultTrollRegistry {

    event Stake(address indexed backer, uint256 indexed trollProfileIndex, uint256 amount, uint256 shares, uint256 backerBalance, uint256 trollBalance, uint256 totalShares);
    event UnstakeRequest(address indexed backer, uint256 indexed trollProfileIndex, uint256 shares, uint256 backerBalance);
    event Unstake(address indexed backer, uint256 indexed trollProfileIndex, uint256 amount, uint256 shares, uint256 approvalDecrement, uint256 trollBalance, uint256 totalShares);
    event UnstakeApproval(address indexed backer, address indexed msgSender, uint256[] signers, uint256 shares);
    event UpdateConfigStore(IOSWAP_ConfigStore newConfigStore);
    event UpdateTrollRegistry(IOSWAP_SideChainTrollRegistry newTrollRegistry);
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
    function govToken() external view returns (IERC20 govToken);
    function configStore() external view returns (IOSWAP_ConfigStore configStore);
    function trollRegistry() external view returns (IOSWAP_SideChainTrollRegistry trollRegistry);
    function backerStakes(address backer) external view returns (Stakes memory backerStakes); // backerStakes[bakcer] = Stakes;
    function stakedBy(uint256 trollProfileIndex, uint256 index) external view returns (address stakedBy); // stakedBy[trollProfileIndex][idx] = backer;
    function stakedByInv(uint256 trollProfileIndex, address backer) external view returns (uint256 stakedByInv); // stakedByInv[trollProfileIndex][backer] = stakedBy_idx;
    function trollStakesBalances(uint256 trollProfileIndex) external view returns (uint256 trollStakesBalances); // trollStakesBalances[trollProfileIndex] = balance
    function trollStakesTotalShares(uint256 trollProfileIndex) external view returns (uint256 trollStakesTotalShares); // trollStakesTotalShares[trollProfileIndex] = shares
    function transactionsCount() external view returns (uint256 transactionsCount);
    function lastTrollTxCount(address troll) external view returns (uint256 lastTrollTxCount); // lastTrollTxCount[troll]
    function usedNonce(bytes32 nonce) external view returns (bool used);

    function updateConfigStore() external;
    function updateTrollRegistry() external;

    function getBackers(uint256 trollProfileIndex) external view returns (address[] memory backers);
    function stakedByLength(uint256 trollProfileIndex) external view returns (uint256 length);

    function stake(uint256 trollProfileIndex, uint256 amount) external returns (uint256 shares);

    function maxWithdrawal(address backer) external view returns (uint256 amount);
    function hashUnstakeRequest(address backer, uint256 trollProfileIndex, uint256 shares, uint256 _nonce) external view returns (bytes32 hash);
    function unstakeRequest(uint256 shares) external;
    function unstakeApprove(bytes[] calldata signatures, address backer, uint256 trollProfileIndex, uint256 shares, uint256 _nonce) external;
    function unstake(address backer, uint256 shares) external;

    function verifyStakedValue(address msgSender, bytes[] calldata signatures, bytes32 paramsHash) external returns (uint256 superTrollCount, uint totalStake, uint256[] memory signers);

    function penalizeSuperTroll(uint256 trollProfileIndex, uint256 amount) external;
}