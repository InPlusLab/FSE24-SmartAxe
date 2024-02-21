// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import "./libraries/ERC20.sol";
import "./libraries/ERC20Capped.sol";

contract OpenSwap is ERC20Capped {
    address public immutable minter;

    constructor(address _minter, address initSupplyTo, uint initSupply, uint256 totalSupply) ERC20("OpenSwap", "OSWAP") ERC20Capped(totalSupply) public {
        minter = _minter;
        _mint(initSupplyTo, initSupply);
    }

    function mint(address account, uint256 amount) external {
        require(msg.sender == minter, "Not from minter");
        _mint(account, amount);
    }
}