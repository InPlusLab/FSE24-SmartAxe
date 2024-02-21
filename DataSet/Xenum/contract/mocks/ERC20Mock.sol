// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract ERC20Mock is ERC20Upgradeable {
	// No point in making upgradeable
	constructor(string memory name, string memory symbol) initializer {
		__ERC20_init(name, symbol);
	}

	function mint(address to, uint256 amount) external {
		_mint(to, amount);
	}

	function burn(address account, uint256 amount) public {
		_burn(account, amount);
	}
}
