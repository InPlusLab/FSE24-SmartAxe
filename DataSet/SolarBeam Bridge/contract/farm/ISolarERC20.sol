// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface ISolarERC20 is IERC20, IERC20Permit {
    function mint(address to, uint256 amount) external;
}
