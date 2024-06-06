pragma solidity ^0.8.1;

interface IMintBurn1155 {
    function mint(address account, uint256 tokenId, uint256 amount) external;
    // function mint(address account, uint256 tokenId, uint256 amount, bytes memory data) external;
    function burn(address account, uint256 tokenId, uint256 amount) external;
    // function burn(address account, uint256 tokenId, uint256 amount, bytes memory data) external;
}