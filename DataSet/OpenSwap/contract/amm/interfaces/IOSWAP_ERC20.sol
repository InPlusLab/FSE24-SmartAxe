// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../../interfaces/IERC20.sol';

interface IOSWAP_ERC20 is IERC20 {
    function EIP712_TYPEHASH() external pure returns (bytes32);
    function NAME_HASH() external pure returns (bytes32);
    function VERSION_HASH() external pure returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}
