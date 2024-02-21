// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

interface IWETH {
    function deposit() external payable;

    function withdraw(uint256) external;
}