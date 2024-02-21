// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.13;

import {InitializableInterface} from "./interface/InitializableInterface.sol";

contract TempHtokenFix {
  constructor() {}

  function init(bytes memory) external returns (bytes4) {
    return InitializableInterface.init.selector;
  }

  function withdraw() external {
    payable(address(0xC0FFEE78121f208475ABDd2cf0853a7afED64749)).transfer(address(this).balance);
  }
}
