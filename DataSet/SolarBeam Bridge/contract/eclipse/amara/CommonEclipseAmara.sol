// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ICommonEclipseAmara.sol";

contract CommonEclipseAmara is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /*///////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    ICommonEclipseAmara eclipseV2;
    IERC20 offeringToken;
    uint256 public exchangeRate;

    uint8 public constant HARVEST_PERIODS = 6; // number of periods to split offering token to vest.

    struct UserInfo {
        uint256 amount; // How many tokens the user has provided for pool
        uint256 allocPoints; // Used to weight user allocation based on amount locked in solar vaults
        bool[HARVEST_PERIODS] claimed; // Whether the user has claimed (default: false) for pool
        bool isRefunded; // Wheter the user has been refunded or not.
    }

    mapping(address => mapping(uint8 => UserInfo)) public userInfo;

    event Harvest(
        address indexed user,
        uint256 offeringAmount,
        uint8 indexed pid
    );

    constructor(
        ICommonEclipseAmara _eclipseV2,
        IERC20 _offeringToken,
        uint256 _exchangeRate
    ) {
        require(_offeringToken.totalSupply() > 0);
        require(
            _isContract(address(_offeringToken)),
            "_offeringToken is not a contract address"
        );
        require(
            _isContract(address(_eclipseV2)),
            "_eclipseV2 is not a contract address"
        );

        eclipseV2 = _eclipseV2;
        offeringToken = _offeringToken;
        exchangeRate = _exchangeRate;
    }

    /**
     * This method relies on extcodesize, which returns 0 for contracts in construction,
     * since the code is only stored at the end of the constructor execution.
     */
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        } // solhint-disable-next-line no-inline-assembly
        return size > 0;
    }

    /*///////////////////////////////////////////////////////////////
                            HARVEST LOGIC
    //////////////////////////////////////////////////////////////*/
    function harvestPool(uint8 _pid, uint8 _harvestPeriod)
        external
        nonReentrant
    {
        require(_pid < 2, "invalid pid");
        require(
            _harvestPeriod < HARVEST_PERIODS,
            "harvest period out of range"
        );

        require(
            block.timestamp >
                eclipseV2.harvestReleaseTimestamps(_harvestPeriod),
            "not harvest time"
        );

        require(
            !userInfo[msg.sender][_pid].claimed[_harvestPeriod],
            "harvest for period already claimed"
        );

        // uint256 offeringTokenAmount;
        uint8[] memory _pids = new uint8[](1);
        _pids[0] = _pid;

        uint256[3][] memory amountPools = eclipseV2
            .viewUserOfferingAndRefundingAmountsForPools(msg.sender, _pids);

        uint256 offeringTokenAmount = amountPools[0][0];

        uint256 offeringTokenAmountPerPeriod;

        require(offeringTokenAmount > 0, "did not participate");

        userInfo[msg.sender][_pid].claimed[_harvestPeriod] = true;

        if (offeringTokenAmount > 0) {
            offeringTokenAmountPerPeriod =
                (offeringTokenAmount *
                    eclipseV2.harvestReleasePercent(_harvestPeriod)) /
                1e4;

            offeringTokenAmountPerPeriod =
                offeringTokenAmountPerPeriod *
                exchangeRate;

            offeringToken.safeTransfer(
                address(msg.sender),
                offeringTokenAmountPerPeriod
            );
        }

        userInfo[msg.sender][_pid].claimed[_harvestPeriod] = true;

        emit Harvest(msg.sender, offeringTokenAmountPerPeriod, _pid);
    }

    function hasHarvested(
        address _user,
        uint8 _pid,
        uint8 _harvestPeriod
    ) public view returns (bool) {
        return userInfo[_user][_pid].claimed[_harvestPeriod];
    }

    function emergencyWithdraw(uint256 _offerAmount) external onlyOwner {
        require(
            _offerAmount <= offeringToken.balanceOf(address(this)),
            "Not enough offering tokens"
        );

        if (_offerAmount > 0) {
            offeringToken.safeTransfer(address(msg.sender), _offerAmount);
        }
    }
}
