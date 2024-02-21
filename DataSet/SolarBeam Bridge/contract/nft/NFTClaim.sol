// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

library Errors {
    string constant C1 =
        "whitelist::whitelist length must be equal as amount length";
}

contract NFTClaim is Ownable, ReentrancyGuard {
    // Info of each user for each pool.
    struct UserInfo {
        bool claimed;
        uint256 amount;
    }

    // Info of each pool.
    struct CampaignInfo {
        IERC721 nft;
    }

    // userInfo[_campaignId][_who]
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // mapping to keep track of nft rewards for sweep function
    mapping(address => bool) public nft;

    // CampainInfo[_campaignId];
    CampaignInfo[] public campaignInfo;

    event AddCampaignInfo(uint256 indexed campaignID, IERC721 nft);
    event Whitelist(
        uint256 indexed campaignID,
        address indexed user,
        uint256 indexed amount
    );
    event Claim(address indexed user, uint256 indexed campaignID);
    event AdminRecovery(address indexed nftAddress, uint256 amount);

    function addCampaignInfo(IERC721 _nft) external onlyOwner {
        campaignInfo.push(CampaignInfo({nft: _nft}));
        nft[address(_nft)] = true;
        emit AddCampaignInfo(campaignInfo.length - 1, _nft);
    }

    function campaignInfoLen() external view returns (uint256) {
        return campaignInfo.length;
    }

    function whitelist(
        uint256 _campaignID,
        address[] calldata _whitelist,
        uint256[] calldata _amount
    ) external onlyOwner {
        require(_whitelist.length == _amount.length, Errors.C1);

        for (uint256 i = 0; i < _whitelist.length; i++) {
            UserInfo storage user = userInfo[_campaignID][_whitelist[i]];
            user.amount = _amount[i];
            user.claimed = false;
            emit Whitelist(_campaignID, _whitelist[i], _amount[i]);
        }
    }
}
