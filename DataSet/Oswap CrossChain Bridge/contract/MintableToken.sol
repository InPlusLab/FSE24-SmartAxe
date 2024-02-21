// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./Authorization.sol";

contract MintableToken is Authorization, ERC20Burnable {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        isPermitted[msg.sender] = true;
    }

    function mint(address account, uint256 amount) public auth returns (bool) {
        _mint(account, amount);
        return true;
    }
}
