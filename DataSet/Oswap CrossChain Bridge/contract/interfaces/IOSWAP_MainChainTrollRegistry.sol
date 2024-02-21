// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./I_TrollNFT.sol";
import "./IAuthorization.sol";
import "./IOSWAP_VotingManager.sol";

interface IOSWAP_MainChainTrollRegistry is IAuthorization, IERC721Receiver {

    event Shutdown(address indexed account);
    event Resume();

    event AddTroll(address indexed owner, address indexed troll, uint256 indexed trollProfileIndex, bool isSuperTroll);
    event UpdateTroll(uint256 indexed trollProfileIndex, address indexed oldTroll, address indexed newTroll);

    event UpdateNFT(I_TrollNFT indexed nft, TrollType trollType);
    event BlockNftTokenId(I_TrollNFT indexed nft, uint256 indexed tokenId, bool blocked);
    event UpdateVotingManager(IOSWAP_VotingManager newVotingManager);
    event Upgrade(address newTrollRegistry);

    event StakeSuperTroll(address indexed backer, uint256 indexed trollProfileIndex, I_TrollNFT nft, uint256 tokenId, uint256 stakesChange, uint256 stakesBalance);
    event StakeGeneralTroll(address indexed backer, uint256 indexed trollProfileIndex, I_TrollNFT nft, uint256 tokenId, uint256 stakesChange, uint256 stakesBalance);
    event UnstakeSuperTroll(address indexed backer, uint256 indexed trollProfileIndex, I_TrollNFT nft, uint256 tokenId, uint256 stakesChange, uint256 stakesBalance);
    event UnstakeGeneralTroll(address indexed backer, uint256 indexed trollProfileIndex, I_TrollNFT nft, uint256 tokenId, uint256 stakesChange, uint256 stakesBalance);

    enum TrollType {NotSpecified, SuperTroll, GeneralTroll, BlockedSuperTroll, BlockedGeneralTroll}
    // trolls in Locked state can still participate in voting (to replicate events in main chain) in side chain, but cannot do cross chain transactions

    struct TrollProfile {
        address owner;
        address troll;
        TrollType trollType;
        uint256 nftCount;
    }
    struct StakeTo {
        I_TrollNFT nft;
        uint256 tokenId;
        uint256 trollProfileIndex;
        uint256 timestamp;
    }
    struct Staked {
        address backer;
        uint256 index;
    }
    struct StakedInv {
        uint256 trollProfileIndex;
        uint256 index;
    }
    struct Nft {
        I_TrollNFT nft;
        uint256 tokenId;
    }

    function govToken() external view returns (IERC20 govToken);
    function votingManager() external view returns (IOSWAP_VotingManager votingManager);
    function trollProfiles(uint256 trollProfileIndex) external view returns (TrollProfile memory trollProfile); // trollProfiles[trollProfileIndex] = {owner, troll, trollType, nftCount}
    function trollProfileInv(address troll) external view returns (uint256 trollProfileInv); // trollProfileInv[troll] = trollProfileIndex
    function ownerTrolls(address owner, uint256 index) external view returns (uint256 ownerTrolls); // ownerTrolls[owner][idx] = trollProfileIndex
    function stakeTo(address backer, uint256 index) external view returns (StakeTo memory stakeTo);  // stakeTo[backer][idx] = {nft, tokenId, trollProfileIndex}
    function stakeToInv(I_TrollNFT nft, uint256 tokenId) external view returns (Staked memory stakeToInv);   // stakeToInv[nft][tokenId] = {backer, idx}
    function stakedBy(uint256 trollProfileIndex, uint256 index) external view returns (Nft memory stakedBy);  // stakedBy[trollProfileIndex][idx2] = {nft, tokenId}
    function stakedByInv(I_TrollNFT nft, uint256 tokenId) external view returns (StakedInv memory takedByInv);   // stakedByInv[nft][tokenId] = {trollProfileIndex, idx2}
    function trollNft(uint256 index) external view returns (I_TrollNFT);
    function trollNftInv(I_TrollNFT nft) external view returns (uint256 trollNftInv);
    function nftType(I_TrollNFT nft) external view returns (TrollType nftType);
    function blockedNftTokenId(I_TrollNFT nft, uint256 tokenId) external view returns (bool blockedNftTokenId); // blockedNftTokenId[nft][tokenId] = true if blocked

    function totalStake() external view returns (uint256 totalStake);
    function stakeOf(address) external view returns (uint256 stakeOf); // stakeOf[owner]

    function newTrollRegistry() external view returns (address newTrollRegistry);

    function initAddress(IOSWAP_VotingManager _votingManager) external;

    /*
     * upgrade
     */
    function updateVotingManager() external;
    function upgrade(address _trollRegistry) external;
    function upgradeByAdmin(address _trollRegistry) external;

    /*
     * pause / resume
     */
    function paused() external view returns (bool);
    function shutdownByAdmin() external;
    function shutdownByVoting() external;
    function resume() external;

    /*
     * states variables getter
     */
    function ownerTrollsLength(address owner) external view returns (uint256 length);
    function trollProfilesLength() external view returns (uint256 length);
    function getTrolls(uint256 start, uint256 length) external view returns (TrollProfile[] memory trolls);
    function stakeToLength(address backer) external view returns (uint256 length);
    function getStakeTo(address backer) external view returns (StakeTo[] memory);
    function stakedByLength(uint256 trollProfileIndex) external view returns (uint256 length);
    function getStakedBy(uint256 trollProfileIndex) external view returns (Nft[] memory);
    function trollNftLength() external view returns (uint256 length);
    function getTrollProperties(uint256 trollProfileIndex) external view returns (
        TrollProfile memory troll,
        Nft[] memory nfts,
        address[] memory backers
    );
    function getTrollPropertiesByAddress(address trollAddress) external view returns (
        TrollProfile memory troll,
        Nft[] memory nfts,
        address[] memory backers
    );
    function getTrollByNft(I_TrollNFT nft, uint256 tokenId) external view returns (address troll);

    function updateNft(I_TrollNFT nft, TrollType trolltype) external;

    /*
     * helper functions
     */
    function getStakes(address troll) external view returns (uint256 totalStakes);
    function getStakesByTrollProfile(uint256 trollProfileIndex) external view returns (uint256 totalStakes);

    /*
     * functions called by owner
     */
    function addTroll(address troll, bool _isSuperTroll, bytes calldata signature) external;
    function updateTroll(uint256 trollProfileIndex, address newTroll, bytes calldata signature) external;

    /*
     * functions called by backer
     */
    function stakeSuperTroll(uint256 trollProfileIndex, I_TrollNFT nft, uint256 tokenId) external;
    function stakeGeneralTroll(uint256 trollProfileIndex, I_TrollNFT nft, uint256 tokenId) external;

    // add more stakes to the specified nft/tokenId
    function addStakesSuperTroll(I_TrollNFT nft, uint256 tokenId, uint256 amount) external;
    function addStakesGeneralTroll(I_TrollNFT nft, uint256 tokenId, uint256 amount) external;

    function unstakeSuperTroll(I_TrollNFT nft, uint256 tokenId) external returns (uint256 trollProfileIndex);
    function unstakeGeneralTroll(I_TrollNFT nft, uint256 tokenId) external returns (uint256 trollProfileIndex);

    function backerStaking(address backer, uint256 start, uint256 length) external view returns (StakeTo[] memory stakings);

}

