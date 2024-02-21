// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract mockERC20 is ERC20 {

    constructor() public ERC20("mock ERC20", "ME") {}

    function mint(address to, uint256 value) external {
        _mint(to, value);
    }
}