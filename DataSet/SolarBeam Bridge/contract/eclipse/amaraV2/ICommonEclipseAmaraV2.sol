// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/** @title ICommonEclipse
 * @notice It is an interface for CommonEclipse.sol
 */
abstract contract ICommonEclipseAmaraV2 {
    enum WITHDRAW_TYPE {
        RAISING,
        TAX
    }

    enum HARVEST_TYPE {
        TIMESTAMP,
        PERCENT
    }

    /**
     * @notice External view function to see user offering and refunding amounts for both pools
     * @param _user: user address
     * @param _pids: array of pids
     */
    function viewUserOfferingAndRefundingAmountsForPools(
        address _user,
        uint8[] calldata _pids
    ) external view virtual returns (uint256[3][] memory);
}
