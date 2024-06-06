pragma solidity ^0.8.1;

interface IAnyERC20_legacy {
    function Swapout(uint256 amount, address toAddress) external returns (bool); // lock out or mint to
    function Swapin(bytes32 txhash, address account, uint256 amount) external returns (bool); // lock in or burn from
}