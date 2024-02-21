// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/I_TrollNFT.sol";
import "./Authorization.sol";
import "./OSWAP_VotingManager.sol";

contract OSWAP_MainChainTrollRegistry is Authorization, ERC721Holder, ReentrancyGuard {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    modifier onlyVoting() {
        require(votingManager.isVotingExecutor(msg.sender), "OSWAP: Not from voting");
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
    event AddTroll(address indexed owner, address indexed troll, uint256 indexed trollProfileIndex, bool isSuperTroll);
    event UpdateTroll(uint256 indexed trollProfileIndex, address indexed oldTroll, address indexed newTroll);

    event UpdateNFT(I_TrollNFT indexed nft, TrollType trollType);
    event BlockNftTokenId(I_TrollNFT indexed nft, uint256 indexed tokenId, bool blocked);
    event UpdateVotingManager(OSWAP_VotingManager newVotingManager);
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

    bool private _paused;
    IERC20 public immutable govToken;
    OSWAP_VotingManager public votingManager;

    TrollProfile[] public trollProfiles; // trollProfiles[trollProfileIndex] = {owner, troll, trollType, nftCount}
    mapping(address => uint256) public trollProfileInv; // trollProfileInv[troll] = trollProfileIndex
    mapping(address => uint256[]) public ownerTrolls; // ownerTrolls[owner][idx] = trollProfileIndex
    mapping(address => StakeTo[]) public stakeTo;  // stakeTo[backer][idx] = {nft, tokenId, trollProfileIndex}
    mapping(I_TrollNFT => mapping(uint256 => Staked)) public stakeToInv;   // stakeToInv[nft][tokenId] = {backer, idx}
    mapping(uint256 => Nft[]) public stakedBy;  // stakedBy[trollProfileIndex][idx2] = {nft, tokenId}
    mapping(I_TrollNFT => mapping(uint256 => StakedInv)) public stakedByInv;   // stakedByInv[nft][tokenId] = {trollProfileIndex, idx2}

    I_TrollNFT[] public trollNft;
    mapping(I_TrollNFT => uint256) public trollNftInv;
    mapping(I_TrollNFT => TrollType) public nftType;

    uint256 public totalStake;
    mapping(address => uint256) public stakeOf; // stakeOf[owner]

    address public newTrollRegistry;

    constructor(IERC20 _govToken, I_TrollNFT[] memory _superTrollNft, I_TrollNFT[] memory _generalTrollNft) {
        govToken = _govToken;

        uint256 length = _superTrollNft.length;
        for (uint256 i = 0 ; i < length ; i++) {
            I_TrollNFT nft = _superTrollNft[i];
            trollNftInv[nft] = i;
            trollNft.push(nft);
            nftType[nft] = TrollType.SuperTroll;
            emit UpdateNFT(nft, TrollType.SuperTroll);
        }

        uint256 length2 = _generalTrollNft.length;
        for (uint256 i = 0 ; i < length2 ; i++) {
            I_TrollNFT nft = _generalTrollNft[i];
            trollNftInv[nft] = i + length;
            trollNft.push(nft);
            nftType[nft] = TrollType.GeneralTroll;
            emit UpdateNFT(nft, TrollType.GeneralTroll);
        }

        // make trollProfiles[0] invalid and trollProfiles.length > 0
        trollProfiles.push(TrollProfile({owner:address(0), troll:address(0), trollType:TrollType.NotSpecified, nftCount:0}));
        isPermitted[msg.sender] = true;
    }
    function initAddress(OSWAP_VotingManager _votingManager) external onlyOwner {
        require(address(_votingManager) != address(0), "null address");
        require(address(votingManager) == address(0), "already set");
        votingManager = _votingManager;
        // renounceOwnership();
    }

    /*
     * upgrade
     */
    function updateVotingManager() external {
        OSWAP_VotingManager _votingManager = votingManager.newVotingManager();
        require(address(_votingManager) != address(0), "Invalid config store");
        votingManager = _votingManager;
        emit UpdateVotingManager(votingManager);
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
    function paused() public view returns (bool) {
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

    /*
     * states variables getter
     */
    function ownerTrollsLength(address owner) external view returns (uint256 length) {
        length = ownerTrolls[owner].length;
    }
    function trollProfilesLength() external view returns (uint256 length) {
        length = trollProfiles.length;
    }
    function getTrolls(uint256 start, uint256 length) external view returns (TrollProfile[] memory trolls) {
        if (start < trollProfiles.length) {
            if (start + length > trollProfiles.length) {
                length = trollProfiles.length - start;
            }
            trolls = new TrollProfile[](length);
            for (uint256 i ; i < length ; i++) {
                trolls[i] = trollProfiles[i + start];
            }
        }
    }
    function stakeToLength(address backer) external view returns (uint256 length) {
        length = stakeTo[backer].length;
    }
    function getStakeTo(address backer) external view returns (StakeTo[] memory) {
        return stakeTo[backer];
    }
    function stakedByLength(uint256 trollProfileIndex) external view returns (uint256 length) {
        length = stakedBy[trollProfileIndex].length;
    }
    function getStakedBy(uint256 trollProfileIndex) external view returns (Nft[] memory) {
        return stakedBy[trollProfileIndex];
    }
    function trollNftLength() external view returns (uint256 length) {
        length = trollNft.length;
    }
    function getTrollProperties(uint256 trollProfileIndex) public view returns (
        TrollProfile memory troll,
        Nft[] memory nfts,
        address[] memory backers
    ){
        troll = trollProfiles[trollProfileIndex];
        nfts = stakedBy[trollProfileIndex];
        uint256 length = nfts.length;
        backers = new address[](length);
        for (uint256 i ; i < length ; i++) {
            backers[i] = stakeToInv[nfts[i].nft][nfts[i].tokenId].backer;
        }
    }
    function getTrollPropertiesByAddress(address trollAddress) external view returns (
        TrollProfile memory troll,
        Nft[] memory nfts,
        address[] memory backers
    ) {
        return getTrollProperties(trollProfileInv[trollAddress]);
    }
    function getTrollByNft(I_TrollNFT nft, uint256 tokenId) external view returns (address troll) {
        uint256 trollProfileIndex = stakedByInv[nft][tokenId].trollProfileIndex;
        require(trollProfileIndex != 0, "not exists");
        troll = trollProfiles[trollProfileIndex].troll;
    }

    function updateNft(I_TrollNFT nft, TrollType trolltype) external onlyOwner {
        // new nft or block the nft if exists
        TrollType oldType = nftType[nft];
        bool isNew = trollNft.length == 0 || trollNft[trollNftInv[nft]] != nft;
        if (isNew) {
            trollNftInv[nft] = trollNft.length;
            trollNft.push(nft);
        } else {
            require(oldType == TrollType.SuperTroll ? trolltype==TrollType.BlockedSuperTroll : trolltype==TrollType.BlockedGeneralTroll);
        }
        nftType[nft] = trolltype;
        emit UpdateNFT(nft, trolltype);
    }

    /*
     * helper functions
     */
    function getStakes(address troll) public view returns (uint256 totalStakes) {
        uint256 trollProfileIndex = trollProfileInv[troll];
        return getStakesByTrollProfile(trollProfileIndex);
    }
    function getStakesByTrollProfile(uint256 trollProfileIndex) public view returns (uint256 totalStakes) {
        Nft[] storage stakes = stakedBy[trollProfileIndex];
        uint256 length = stakes.length;
        for (uint256 i = 0 ; i < length ; i++) {
            Nft storage staking = stakes[i];
            if (nftType[staking.nft] == TrollType.SuperTroll) {
                totalStakes += staking.nft.stakingBalance(staking.tokenId);
            }
        }
    }

    /*
     * functions called by owner
     */
    function addTroll(address troll, bool _isSuperTroll, bytes calldata signature) external whenNotPaused {
        // check if owner has the troll's private key to sign message
        address trollOwner = msg.sender;

        require(troll != address(0), "Invalid troll");
        require(trollProfileInv[troll] == 0, "troll already exists");
        require(trollOwner != troll && trollProfileInv[trollOwner] == 0, "owner cannot be a troll");
        require(!isPermitted[troll], "permitted address cannot be a troll");
        require(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abi.encodePacked(msg.sender)))).recover(signature) == troll, "invalid troll signature");

        uint256 trollProfileIndex = trollProfiles.length;
        trollProfileInv[troll] = trollProfileIndex;
        ownerTrolls[trollOwner].push(trollProfileIndex);
        trollProfiles.push(TrollProfile({owner:trollOwner, troll:troll, trollType:_isSuperTroll ? TrollType.SuperTroll : TrollType.GeneralTroll, nftCount:0}));
        emit AddTroll(trollOwner, troll, trollProfileIndex, _isSuperTroll);
    }
    function updateTroll(uint256 trollProfileIndex, address newTroll, bytes calldata signature) external {
        // check if owner has the troll's private key to sign message
        require(newTroll != address(0), "Invalid troll");
        require(trollProfileInv[newTroll] == 0, "newTroll already exists");
        require(!isPermitted[newTroll], "permitted address cannot be a troll");
        require(trollProfiles[trollProfileIndex].owner == msg.sender, "not from owner");
        require(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abi.encodePacked(msg.sender)))).recover(signature) == newTroll, "invalid troll signature");

        TrollProfile storage troll = trollProfiles[trollProfileIndex];
        address oldTroll = troll.troll;
        troll.troll = newTroll;
        trollProfileInv[newTroll] = trollProfileIndex;
        delete trollProfileInv[oldTroll];
        emit UpdateTroll(trollProfileIndex, oldTroll, newTroll);
    }

    /*
     * functions called by backer
     */
    function _stakeMainChain(uint256 trollProfileIndex, I_TrollNFT nft, uint256 tokenId) internal returns (uint256 stakes) {
        nft.safeTransferFrom(msg.sender, address(this), tokenId);
        stakes = nft.stakingBalance(tokenId);
        stakeOf[msg.sender] += stakes;
        totalStake += stakes;

        address backer = msg.sender;
        TrollProfile storage troll = trollProfiles[trollProfileIndex];
        require(troll.trollType == nftType[nft], "Invalid nft type");
        uint256 index = stakeTo[backer].length;
        Staked memory staked = Staked({backer: backer, index: index});
        stakeToInv[nft][tokenId] = staked;
        stakeTo[backer].push(StakeTo({nft:nft, tokenId: tokenId, trollProfileIndex: trollProfileIndex, timestamp: block.timestamp}));
        uint256 index2 = stakedBy[trollProfileIndex].length;
        stakedByInv[nft][tokenId] = StakedInv({trollProfileIndex: trollProfileIndex, index: index2});
        stakedBy[trollProfileIndex].push(Nft({nft:nft, tokenId:tokenId}));
        troll.nftCount++;

        votingManager.updateWeight(msg.sender); 
    }
    function stakeSuperTroll(uint256 trollProfileIndex, I_TrollNFT nft, uint256 tokenId) external nonReentrant whenNotPaused {
        require(trollProfiles[trollProfileIndex].trollType == TrollType.SuperTroll, "Invalid type");
        (uint256 stakes) = _stakeMainChain(trollProfileIndex, nft, tokenId);
        emit StakeSuperTroll(msg.sender, trollProfileIndex, nft, tokenId, stakes, stakeOf[msg.sender]);
    }
    function stakeGeneralTroll(uint256 trollProfileIndex, I_TrollNFT nft, uint256 tokenId) external nonReentrant whenNotPaused {
        require(trollProfiles[trollProfileIndex].trollType == TrollType.GeneralTroll, "Invalid type");
        (uint256 stakes) = _stakeMainChain(trollProfileIndex, nft, tokenId);
        emit StakeGeneralTroll(msg.sender, trollProfileIndex, nft, tokenId, stakes, stakeOf[msg.sender]);
    }

    // add more stakes to the specified nft/tokenId
    function _addStakesSuperTroll(I_TrollNFT nft, uint256 tokenId, uint256 amount) internal returns (uint256 trollProfileIndex){
        trollProfileIndex = stakedByInv[nft][tokenId].trollProfileIndex;
        Staked storage staked = stakeToInv[nft][tokenId];
        require(staked.backer == msg.sender, "not from backer");
        govToken.safeTransferFrom(msg.sender, address(this), amount);
        govToken.approve(address(nft), amount);
        nft.addStakes(tokenId, amount);
        stakeOf[msg.sender] += amount;
        totalStake += amount;

        votingManager.updateWeight(msg.sender); 
    }
    function addStakesSuperTroll(I_TrollNFT nft, uint256 tokenId, uint256 amount) external nonReentrant whenNotPaused {
        uint256 trollProfileIndex = _addStakesSuperTroll(nft, tokenId, amount);
        require(trollProfiles[trollProfileIndex].trollType == TrollType.SuperTroll, "Invalid type");
        emit StakeSuperTroll(msg.sender, trollProfileIndex, nft, tokenId, amount, stakeOf[msg.sender]);
    }
    function addStakesGeneralTroll(I_TrollNFT nft, uint256 tokenId, uint256 amount) external nonReentrant whenNotPaused {
        uint256 trollProfileIndex = _addStakesSuperTroll(nft, tokenId, amount);
        require(trollProfiles[trollProfileIndex].trollType == TrollType.GeneralTroll, "Invalid type");
        emit StakeGeneralTroll(msg.sender, trollProfileIndex, nft, tokenId, amount, stakeOf[msg.sender]);
    }

    function _unstakeMainChain(I_TrollNFT nft, uint256 tokenId) internal returns (uint256 trollProfileIndex, uint256 stakes) {
        address backer = msg.sender;
        StakedInv storage _stakedByInv = stakedByInv[nft][tokenId];
        // require(staked.backer != address(0));
        trollProfileIndex = _stakedByInv.trollProfileIndex;
        require(trollProfileIndex != 0);

        uint256 indexToBeReplaced;
        uint256 lastIndex;
        // update stakeTo / stakeToInv
        {
        StakeTo[] storage _staking = stakeTo[backer];
        lastIndex = _staking.length - 1;
        Staked storage _staked = stakeToInv[nft][tokenId];
        require(_staked.backer == backer, "not a backer");
        indexToBeReplaced = _staked.index;
        if (indexToBeReplaced != lastIndex) {
            StakeTo storage last = _staking[lastIndex];
            _staking[indexToBeReplaced] = last;
            stakeToInv[last.nft][last.tokenId].index = indexToBeReplaced;
        }
        _staking.pop();
        delete stakeToInv[nft][tokenId];
        }
        // update stakedBy / stakedByInv
        {
        indexToBeReplaced = stakedByInv[nft][tokenId].index;
        Nft[] storage _staked = stakedBy[trollProfileIndex];
        lastIndex = _staked.length - 1;
        if (indexToBeReplaced != lastIndex) {
            Nft storage last = _staked[lastIndex];
            _staked[indexToBeReplaced] = last;
            stakedByInv[last.nft][last.tokenId].index = indexToBeReplaced;
        }
        _staked.pop();
        delete stakedByInv[nft][tokenId];
        }
        trollProfiles[trollProfileIndex].nftCount--;

        stakes = nft.stakingBalance(tokenId);
        stakeOf[msg.sender] -= stakes;
        totalStake -= stakes;
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        votingManager.updateWeight(msg.sender); 
    }
    function unstakeSuperTroll(I_TrollNFT nft, uint256 tokenId) external nonReentrant whenNotPaused returns (uint256 trollProfileIndex) {
        uint256 stakes;
        (trollProfileIndex, stakes) = _unstakeMainChain(nft, tokenId);
        require(trollProfiles[trollProfileIndex].trollType == TrollType.SuperTroll, "Invalid type");
        emit UnstakeSuperTroll(msg.sender, trollProfileIndex, nft, tokenId, stakes, stakeOf[msg.sender]);
    }
    function unstakeGeneralTroll(I_TrollNFT nft, uint256 tokenId) external nonReentrant whenNotPaused returns (uint256 trollProfileIndex) {
        uint256 stakes;
        (trollProfileIndex, stakes) = _unstakeMainChain(nft, tokenId);
        require(trollProfiles[trollProfileIndex].trollType == TrollType.GeneralTroll, "Invalid type");
        emit UnstakeGeneralTroll(msg.sender, trollProfileIndex, nft, tokenId, stakes, stakeOf[msg.sender]);
    }


    function backerStaking(address backer, uint256 start, uint256 length) external view returns (StakeTo[] memory stakings) {
        StakeTo[] storage _backerStakings = stakeTo[backer];

        if (start + length > _backerStakings.length) {
            length = _backerStakings.length - start;
        }
        stakings = new StakeTo[](length);

        uint256 j = start;
        for (uint256 i = 0 ; i < length ; i++) {
            stakings[i] = _backerStakings[j + start];
            j++;
        }
    }
}

