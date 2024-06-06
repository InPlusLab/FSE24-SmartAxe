pragma solidity ^0.8.1;

interface IMintBurn {
    function mint(address account, uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;
    // function burn(address account, uint256 amount) external;
}