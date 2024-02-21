// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/** @title ICommonEclipse
 * @notice It is an interface for CommonEclipse.sol
 */
abstract contract ICommonEclipseAmara {
    enum WITHDRAW_TYPE {
        RAISING,
        TAX
    }

    enum HARVEST_TYPE {
        TIMESTAMP,
        PERCENT
    }

    /**
     * @notice It sets parameters for pool
     * @param _offeringAmountPool: offering amount (in tokens)
     * @param _raisingAmountPool: raising amount (in LP tokens)
     * @param _baseLimitInLP: base limit per user (in LP tokens)
     * @param _hasTax: if the pool has a tax
     * @param _pid: poolId
     * @dev This function is only callable by owner.
     */
    function setPool(
        uint256 _offeringAmountPool,
        uint256 _raisingAmountPool,
        uint256 _baseLimitInLP,
        bool _hasTax,
        uint8 _pid
    ) external virtual;

    /**
     * @notice It allows users to deposit LP tokens to pool
     * @param _amount: the number of LP token used (18 decimals)
     * @param _pid: pool id
     */
    function depositPool(uint256 _amount, uint8 _pid) external virtual;

    /**
     * @notice It allows users to harvest from pool
     * @param _pid: pool id
     * @param _harvestPeriod: chosen harvest period to claim
     */
    function harvestPool(uint8 _pid, uint8 _harvestPeriod) external virtual;

    /**
     * @notice It allows owner to update start and end blocks of the sale
     * @param _startBlock: block number sale starts
     * @param _endBlock: block number sale ends
     */
    function updateStartAndEndBlocks(uint256 _startBlock, uint256 _endBlock)
        external
        virtual;

    /**
     * @notice It allows owner to set the multiplier information
     * @param _multipliers: encoded multipliers for zero, seven and thirty day vaults
     * @dev encoded args are (uint8,uint8,uint8,uint8[2][3],uint8[2][3],uint8[2][3])
     * (0 decimals)
     */
    function setMultipliers(bytes memory _multipliers) public virtual;

    /**
     * @notice It allows owner to set the threshold for eligibility
     * @param _eligibilityThreshold: amount of solar staked in vaults to be eligibile
     */
    function setEligibilityThreshold(uint256 _eligibilityThreshold)
        public
        virtual;

    /**
     * @notice It withdraws raisingAmount + taxes for a pool
     * @dev can only withdraw after the sale is finished
     * @param _type: withdraw type
     * @param _pid: pool id
     */
    function finalWithdraw(WITHDRAW_TYPE _type, uint8 _pid) external virtual;

    /**
     * @notice It returns the tax overflow rate calculated for a pool
     * @dev 100,000,000,000 means 0.1 (10%) / 1 means 0.0000000000001 (0.0000001%) / 1,000,000,000,000 means 1 (100%)
     * @param _pid: poolId
     * @return It returns the tax percentage
     */
    function viewPoolTaxRateOverflow(uint256 _pid)
        external
        virtual
        returns (uint256);

    /**
     * @notice External view function to see user allocations for both pools
     * @param _user: user address
     * @param _pids[]: array of pids
     */
    function viewUserAllocationPools(address _user, uint8[] calldata _pids)
        external
        virtual
        returns (uint256[] memory);

    /**
     * @notice External view function to see user offering and refunding amounts for both pools
     * @param _user: user address
     * @param _pids: array of pids
     */
    function viewUserOfferingAndRefundingAmountsForPools(
        address _user,
        uint8[] calldata _pids
    ) external view virtual returns (uint256[3][] memory);

    /**
     * @notice It allows users to withdraw LP tokens to pool
     * @param _amount: the number of LP token used (18 decimals)
     * @param _pid: pool id
     */
    function withdrawPool(uint256 _amount, uint8 _pid) external virtual;

    /**
     * @notice It allows the admin to end sale and start claim
     * @dev This function is only callable by owner.
     */
    function enableClaim() external virtual;

    function harvestReleasePercent(uint256)
        external
        view
        virtual
        returns (uint256);

    function harvestReleaseTimestamps(uint256)
        external
        view
        virtual
        returns (uint256);

    function harvestReleaseBlocks(uint256)
        external
        view
        virtual
        returns (uint256);
}
