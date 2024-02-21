// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

interface IOSWAP_HybridRouterRegistry {
    event ProtocolRegister(address indexed factory, bytes32 name, uint256 fee, uint256 feeBase, uint256 typeCode);
    event PairRegister(address indexed factory, address indexed pair, address token0, address token1);
    event CustomPairRegister(address indexed pair, uint256 fee, uint256 feeBase, uint256 typeCode);

    struct Protocol {
        bytes32 name;
        uint256 fee;
        uint256 feeBase;
        uint256 typeCode;
    }
    struct Pair {
        address factory;
        address token0;
        address token1;
    }
    struct CustomPair {
        uint256 fee;
        uint256 feeBase;
        uint256 typeCode;
    }


    function protocols(address) external view returns (
        bytes32 name,
        uint256 fee,
        uint256 feeBase,
        uint256 typeCode
    );
    function pairs(address) external view returns (
        address factory,
        address token0,
        address token1
    );
    function customPairs(address) external view returns (
        uint256 fee,
        uint256 feeBase,
        uint256 typeCode
    );
    function protocolList(uint256) external view returns (address);
    function protocolListLength() external view returns (uint256);

    function governance() external returns (address);

    function registerProtocol(bytes32 _name, address _factory, uint256 _fee, uint256 _feeBase, uint256 _typeCode) external;

    function registerPair(address token0, address token1, address pairAddress, uint256 fee, uint256 feeBase, uint256 typeCode) external;
    function registerPairByIndex(address _factory, uint256 index) external;
    function registerPairsByIndex(address _factory, uint256[] calldata index) external;
    function registerPairByTokens(address _factory, address _token0, address _token1) external;
    function registerPairByTokensV3(address _factory, address _token0, address _token1, uint256 pairIndex) external;
    function registerPairsByTokens(address _factory, address[] calldata _token0, address[] calldata _token1) external;
    function registerPairsByTokensV3(address _factory, address[] calldata _token0, address[] calldata _token1, uint256[] calldata pairIndex) external;
    function registerPairByAddress(address _factory, address pairAddress) external;
    function registerPairsByAddress(address _factory, address[] memory pairAddress) external;
    function registerPairsByAddress2(address[] memory _factory, address[] memory pairAddress) external;

    function getPairTokens(address[] calldata pairAddress) external view returns (address[] memory token0, address[] memory token1);
    function getTypeCode(address pairAddress) external view returns (uint256 typeCode);
    function getFee(address pairAddress) external view returns (uint256 fee, uint256 feeBase);
}