// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import '../architecture/OnlySourceFunctionality.sol';
import '../libraries/SmartApprove.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ITestDEX} from './TestDEX.sol';

error NotInWhitelist(address router);

contract TestOnlySource is OnlySourceFunctionality {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    constructor(
        uint256 _fixedCryptoFee,
        uint256 _RubicPlatformFee,
        address[] memory _tokens,
        uint256[] memory _minTokenAmounts,
        uint256[] memory _maxTokenAmounts,
        address _admin
    ) {
        initialize(
            _fixedCryptoFee,
            _RubicPlatformFee,
            _tokens,
            _minTokenAmounts,
            _maxTokenAmounts,
            _admin
        );
    }

    function initialize(
        uint256 _fixedCryptoFee,
        uint256 _RubicPlatformFee,
        address[] memory _tokens,
        uint256[] memory _minTokenAmounts,
        uint256[] memory _maxTokenAmounts,
        address _admin
    ) private initializer {
        __OnlySourceFunctionalityInit(
            _fixedCryptoFee,
            _RubicPlatformFee,
            _tokens,
            _minTokenAmounts,
            _maxTokenAmounts,
            _admin
        );
    }

    function crossChainWithSwap(
        BaseCrossChainParams calldata _params,
        string calldata _providerName
    )
        external
        payable
        nonReentrant
        whenNotPaused
        eventEmitter(_params, _providerName)
    {
        IntegratorFeeInfo memory _info = integratorToFeeInfo[
            _params.integrator
        ];

        IERC20(_params.srcInputToken).transferFrom(
            msg.sender,
            address(this),
            _params.srcInputAmount
        );

        accrueFixedCryptoFee(_params.integrator, _info);

        uint256 _amountIn = accrueTokenFees(
            _params.integrator,
            _info,
            _params.srcInputAmount,
            0,
            _params.srcInputToken
        );

        SmartApprove.smartApprove(
            _params.srcInputToken,
            _amountIn,
            _params.router
        );

        ITestDEX(_params.router).swap(
            _params.srcInputToken,
            _amountIn,
            _params.dstOutputToken
        );
    }
}
