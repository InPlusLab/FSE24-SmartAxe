// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;


import '@openzeppelin/contracts/access/TimelockController.sol';

contract TimeLock is TimelockController{
     constructor(uint256 minDelay, address[] memory proposers, address[] memory executors) public TimelockController(minDelay, proposers, executors) {
     }

}


