// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

interface ISmartRouter {
    enum InputType {
        AMOUNT_IN,
        AMOUNT_OUT
    }

    struct FormattedOffer {
        uint256[] amounts;
        address[] adapters;
        address[] path;
        string[] tokens;
    }

    struct Trade {
        uint256[] amounts;
        address[] path;
        address[] adapters;
    }

    function findBestPath(
        uint256 _amount,
        address _tokenIn,
        address _tokenOut,
        uint256 _maxSteps,
        InputType _inputType
    ) external view returns (FormattedOffer memory);

    function swapNoSplit(
        Trade memory _trade,
        address _to,
        uint256 _fee
    ) external;
}
