// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IBridgeCosignerManager {
    event CosignerAdded(address indexed cosaddr, uint256 chainId);
    event CosignerRemoved(address indexed cosaddr, uint256 chainId);
    struct Cosigner {
        address addr;
        uint256 chainId;
        uint256 index;
        bool active;
    }

    function addCosigner(address cosaddr, uint256 chainId) external;

    function addCosignerBatch(address[] calldata cosaddrs, uint256 chainId)
        external;

    function removeCosigner(address cosaddr) external;

    function removeCosignerBatch(address[] calldata cosaddrs) external;

    function getCosigners(uint256 chainId)
        external
        view
        returns (address[] memory);

    function getCosignCount(uint256 chainId) external view returns (uint8);

    function verify(
        bytes32 commitment,
        uint256 chainId,
        bytes[] calldata signatures
    ) external view returns (bool);
}
