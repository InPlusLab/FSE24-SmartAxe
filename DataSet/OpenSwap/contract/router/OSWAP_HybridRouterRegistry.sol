// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import "./interfaces/IOSWAP_HybridRouterRegistry.sol";
import '../libraries/Ownable.sol';
import '../gov/interfaces/IOAXDEX_Governance.sol';
import '../gov/interfaces/IOAXDEX_VotingExecutor.sol';

interface IFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
}
interface IFactoryV3 {
    function getPair(address tokenA, address tokenB, uint256 index) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
}

interface IPair {
    function token0() external returns (address);
    function token1() external returns (address);
}

contract OSWAP_HybridRouterRegistry is Ownable, IOSWAP_HybridRouterRegistry, IOAXDEX_VotingExecutor {

    modifier onlyVoting() {
        require(IOAXDEX_Governance(governance).isVotingExecutor(msg.sender), "Not from voting");
        _; 
    }

    mapping (address => Pair) public override pairs;
    mapping (address => CustomPair) public override customPairs;
    mapping (address => Protocol) public override protocols;
    address[] public override protocolList;

    address public override governance;

    constructor(address _governance) public {
        governance = _governance;
    }

    function protocolListLength() public override view returns (uint256) {
        return protocolList.length;
    }

    function init(bytes32[] calldata _name, address[] calldata _factory, uint256[] calldata _fee, uint256[] calldata _feeBase, uint256[] calldata _typeCode) external onlyOwner {
        require(protocolList.length == 0 , "Already init");
        uint256 length = _name.length;
        require(length == _factory.length && _factory.length == _fee.length && _fee.length == _typeCode.length, "length not match");
        for (uint256 i = 0 ; i < length ; i++) {
            _registerProtocol(_name[i], _factory[i], _fee[i], _feeBase[i], _typeCode[i]);
        }
    }
    function execute(bytes32[] calldata params) external override {
        require(IOAXDEX_Governance(governance).isVotingContract(msg.sender), "Not from voting");
        require(params.length > 1, "Invalid length");
        bytes32 name = params[0];
        if (params.length == 6) {
            if (name == "registerProtocol") {
                _registerProtocol(params[1], address(bytes20(params[2])), uint256(params[3]), uint256(params[4]), uint256(params[5]));
                return;
            }
        } else if (params.length == 7) {
            if (name == "registerPair") {
                _registerPair(address(bytes20(params[1])), address(bytes20(params[2])), address(bytes20(params[3])), uint256(params[4]), uint256(params[5]), uint256(params[6]));
                return;
            }
        }
        revert("Invalid parameters");
    }
    function registerProtocol(bytes32 _name, address _factory, uint256 _fee, uint256 _feeBase, uint256 _typeCode) external override onlyVoting {
        _registerProtocol(_name, _factory, _fee, _feeBase, _typeCode);
    }
    // register protocol with standard trade fee
    function _registerProtocol(bytes32 _name, address _factory, uint256 _fee, uint256 _feeBase, uint256 _typeCode) internal {
        require(_factory > address(0), "Invalid protocol address");
        require(_fee <= _feeBase, "Fee too large");
        require(_feeBase > 0, "Protocol not regconized");
        protocols[_factory] = Protocol({
            name: _name,
            fee: _fee,
            feeBase: _feeBase,
            typeCode: _typeCode
        });
        protocolList.push(_factory);
        emit ProtocolRegister(_factory, _name, _fee, _feeBase, _typeCode);
    }

    // register individual pair
    function registerPair(address token0, address token1, address pairAddress, uint256 fee, uint256 feeBase, uint256 typeCode) external override onlyVoting {
        _registerPair(token0, token1, pairAddress, fee, feeBase, typeCode);
    }
    function _registerPair(address token0, address token1, address pairAddress, uint256 fee, uint256 feeBase, uint256 typeCode) internal {
        require(token0 > address(0), "Invalid token address");
        require(token0 < token1, "Invalid token order");
        require(pairAddress > address(0), "Invalid pair address");
        // require(token0 == IPair(pairAddress).token0());
        // require(token1 == IPair(pairAddress).token1());
        require(fee <= feeBase, "Fee too large");
        require(feeBase > 0, "Protocol not regconized");

        pairs[pairAddress].factory = address(0);
        pairs[pairAddress].token0 = token0;
        pairs[pairAddress].token1 = token1;
        customPairs[pairAddress].fee = fee;
        customPairs[pairAddress].feeBase = feeBase;
        customPairs[pairAddress].typeCode = typeCode;
        emit PairRegister(address(0), pairAddress, token0, token1);
        emit CustomPairRegister(pairAddress, fee, feeBase, typeCode);
    }

    // register pair with registered protocol
    function registerPairByIndex(address _factory, uint256 index) external override {
        require(protocols[_factory].typeCode > 0, "Protocol not regconized");
        address pairAddress = IFactory(_factory).allPairs(index);
        _registerPair(_factory, pairAddress);
    }
    function registerPairsByIndex(address _factory, uint256[] calldata index) external override {
        require(protocols[_factory].typeCode > 0, "Protocol not regconized");
        uint256 length = index.length;
        for (uint256 i = 0 ; i < length ; i++) {
            address pairAddress = IFactory(_factory).allPairs(index[i]);
            _registerPair(_factory, pairAddress);
        }
    }
    function registerPairByTokens(address _factory, address _token0, address _token1) external override {
        require(protocols[_factory].typeCode > 0 && protocols[_factory].typeCode != 3, "Invalid type");
        address pairAddress = IFactory(_factory).getPair(_token0, _token1);
        _registerPair(_factory, pairAddress);
    }

    function registerPairByTokensV3(address _factory, address _token0, address _token1, uint256 pairIndex) external override {
        require(protocols[_factory].typeCode == 3, "Invalid type");
        address pairAddress = IFactoryV3(_factory).getPair(_token0, _token1, pairIndex);
        _registerPair(_factory, pairAddress);
    }
    function registerPairsByTokens(address _factory, address[] calldata _token0, address[] calldata _token1) external override {
        require(protocols[_factory].typeCode > 0 && protocols[_factory].typeCode != 3, "Invalid type");
        uint256 length = _token0.length;
        require(length == _token1.length, "array length not match");
        for (uint256 i = 0 ; i < length ; i++) {
            address pairAddress = IFactory(_factory).getPair(_token0[i], _token1[i]);
            _registerPair(_factory, pairAddress);
        }
    }
    function registerPairsByTokensV3(address _factory, address[] calldata _token0, address[] calldata _token1, uint256[] calldata _pairIndex) external override {
        require(protocols[_factory].typeCode == 3, "Invalid type");
        uint256 length = _token0.length;
        require(length == _token1.length, "array length not match");
        for (uint256 i = 0 ; i < length ; i++) {
            address pairAddress = IFactoryV3(_factory).getPair(_token0[i], _token1[i], _pairIndex[i]);
            _registerPair(_factory, pairAddress);
        }
    }
    function registerPairByAddress(address _factory, address pairAddress) external override {
        require(protocols[_factory].typeCode > 0 && protocols[_factory].typeCode != 3, "Protocol not regconized");
        _registerPair(_factory, pairAddress, true);
    }
    function registerPairsByAddress(address _factory, address[] memory pairAddress) external override {
        require(protocols[_factory].typeCode > 0 && protocols[_factory].typeCode != 3, "Protocol not regconized");
        uint256 length = pairAddress.length;
        for (uint256 i = 0 ; i < length ; i++) {
            _registerPair(_factory, pairAddress[i], true);
        }
    }
    function registerPairsByAddress2(address[] memory _factory, address[] memory pairAddress) external override {
        uint256 length = pairAddress.length;
        require(length == _factory.length, "array length not match");
        for (uint256 i = 0 ; i < length ; i++) {
            require(protocols[_factory[i]].typeCode > 0 && protocols[_factory[i]].typeCode != 3, "Protocol not regconized");
            _registerPair(_factory[i], pairAddress[i], true);
        }
    }

    function _registerPair(address _factory, address pairAddress) internal {
        _registerPair(_factory, pairAddress, false);
    }
    function _registerPair(address _factory, address pairAddress, bool checkPairAddress) internal {
        require(pairAddress > address(0), "Invalid pair address/Pair not found");
        address token0 = IPair(pairAddress).token0();
        address token1 = IPair(pairAddress).token1();
        require(token0 < token1, "Invalid tokens order");
        if (checkPairAddress) {
            address _pairAddress = IFactory(_factory).getPair(token0, token1);
            require(pairAddress == _pairAddress, "invalid pair");
        }
        pairs[pairAddress].factory = _factory;
        pairs[pairAddress].token0 = token0;
        pairs[pairAddress].token1 = token1;
        emit PairRegister(_factory, pairAddress, token0, token1);
    }

    function getPairTokens(address[] calldata pairAddress) external override view returns (address[] memory token0, address[] memory token1) {
        uint256 length = pairAddress.length;
        token0 = new address[](length);
        token1 = new address[](length);
        for (uint256 i = 0 ; i < length ; i++) {
            Pair storage pair = pairs[pairAddress[i]];
            token0[i] = pair.token0;
            token1[i] = pair.token1;
        }
    }
    // caller needs to check if typeCode = 0 (or other invalid value)
    function getTypeCode(address pairAddress) external override view returns (uint256 typeCode) {
        address factory = pairs[pairAddress].factory;
        if (factory != address(0)) {
            typeCode = protocols[factory].typeCode;
        } else {
            typeCode = customPairs[pairAddress].typeCode;
        }
    }
    // if getFee() is called without prior getTypeCode(), caller needs to check if feeBase = 0
    function getFee(address pairAddress) external override view returns (uint256 fee, uint256 feeBase) {
        address factory = pairs[pairAddress].factory;
        if (factory != address(0)) {
            fee = protocols[factory].fee;
            feeBase = protocols[factory].feeBase;
        } else {
            feeBase = customPairs[pairAddress].feeBase;
            fee = customPairs[pairAddress].fee;
        }
    }
}