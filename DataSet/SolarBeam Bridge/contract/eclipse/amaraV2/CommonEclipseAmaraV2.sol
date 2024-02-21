// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ICommonEclipseAmaraV2.sol";
import "../v2/CommonEclipseV2.sol";

contract CommonEclipseAmaraV2 is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /*///////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    CommonEclipseV2 eclipseV2;
    CommonEclipseV2 amaraV2;
    IERC20 offeringToken;
    uint256 public exchangeRate;

    uint8 public constant HARVEST_PERIODS = 6; // number of periods to split offering token to vest.

    struct UserInfo {
        uint256 amount; // How many tokens the user has provided for pool
        uint256 allocPoints; // Used to weight user allocation based on amount locked in solar vaults
        bool[HARVEST_PERIODS] claimed; // Whether the user has claimed (default: false) for pool
        bool isRefunded; // Wheter the user has been refunded or not.
    }

    mapping(address => mapping(uint8 => UserInfo)) public _userInfo;

    event Harvest(
        address indexed user,
        uint256 offeringAmount,
        uint8 indexed pid
    );

    constructor(
        CommonEclipseV2 _eclipseV2,
        CommonEclipseV2 _amaraV2,
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
        require(
            _isContract(address(_amaraV2)),
            "_amaraV2 is not a contract address"
        );
        amaraV2 = _amaraV2;
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

    function calculateAmountToClaim(
        address _user,
        uint8 _pid,
        uint8 _harvestPeriod
    ) public view returns (uint256 result) {
        uint8[] memory _pids = new uint8[](1);
        _pids[0] = _pid;

        uint256[3][] memory amountPools = eclipseV2
            .viewUserOfferingAndRefundingAmountsForPools(_user, _pids);

        uint256 offeringTokenAmount = amountPools[0][0];

        uint256 offeringTokenAmountPerPeriod = 0;
        result = 0;

        if (offeringTokenAmount > 0) {
            if (_pid == 0) {
                //BASIC
                if (!amaraV2.hasHarvested(_user, _pid, _harvestPeriod)) {
                    result =
                        ((offeringTokenAmount *
                            eclipseV2.harvestReleasePercent(_harvestPeriod)) /
                            1e4) *
                        exchangeRate;
                }
            } else {
                (uint256 amount, , ) = eclipseV2.userInfo(_user, _pid);

                (
                    uint256 raisingAmount,
                    uint256 offeringAmount,
                    ,
                    ,
                    ,
                    ,

                ) = eclipseV2.poolInfo(_pid);

                uint256 refundAmount = amountPools[0][1];

                /* TOTAL TOKENS */
                uint256 correctOfferingAmount = ((amount - refundAmount) *
                    offeringAmount) / raisingAmount;

                uint256 correctOfferingAmountPerPeriod = ((correctOfferingAmount *
                        eclipseV2.harvestReleasePercent(_harvestPeriod)) /
                        1e4) * exchangeRate;

                if (amaraV2.hasHarvested(_user, _pid, _harvestPeriod)) {
                    /* AMOUNT ALREADY PAID */
                    offeringTokenAmountPerPeriod =
                        ((offeringTokenAmount *
                            eclipseV2.harvestReleasePercent(_harvestPeriod)) /
                            1e4) *
                        exchangeRate;
                }

                if (
                    offeringTokenAmountPerPeriod >
                    correctOfferingAmountPerPeriod
                ) {
                    result = 0;
                } else {
                    result =
                        correctOfferingAmountPerPeriod -
                        offeringTokenAmountPerPeriod;
                }
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                            HARVEST LOGIC
    //////////////////////////////////////////////////////////////*/
    function harvestPool(uint8 _pid, uint8 _harvestPeriod)
        external
        nonReentrant
    {
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
            !_userInfo[msg.sender][_pid].claimed[_harvestPeriod],
            "harvest for period already claimed"
        );

        uint256 userAmount = calculateAmountToClaim(
            msg.sender,
            _pid,
            _harvestPeriod
        );

        require(userAmount > 0, "no tokens to claim");

        _userInfo[msg.sender][_pid].claimed[_harvestPeriod] = true;

        offeringToken.safeTransfer(address(msg.sender), userAmount);

        _userInfo[msg.sender][_pid].claimed[_harvestPeriod] = true;

        emit Harvest(msg.sender, userAmount, _pid);
    }

    function hasHarvested(
        address _user,
        uint8 _pid,
        uint8 _harvestPeriod
    ) public view returns (bool) {
        uint256 userAmount = calculateAmountToClaim(
            _user,
            _pid,
            _harvestPeriod
        );

        return
            _userInfo[_user][_pid].claimed[_harvestPeriod] || userAmount == 0;
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
