pragma solidity ^0.8.1;

interface ITransfer {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}
