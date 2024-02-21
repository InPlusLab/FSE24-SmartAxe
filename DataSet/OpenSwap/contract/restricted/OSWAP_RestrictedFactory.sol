// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;


import './interfaces/IOSWAP_RestrictedFactory.sol';
import '../gov/interfaces/IOAXDEX_Governance.sol';
import '../commons/interfaces/IOSWAP_PairBase.sol';
import '../oracle/interfaces/IOSWAP_OracleAdaptor2.sol';
import '../libraries/Ownable.sol';
import '../commons/OSWAP_PausableFactory.sol';

contract OSWAP_RestrictedFactory is IOSWAP_RestrictedFactory, OSWAP_PausableFactory, Ownable { 

    modifier onlyVoting() {
        require(IOAXDEX_Governance(governance).isVotingExecutor(msg.sender), "Not from voting");
        _; 
    }

    uint256 constant FEE_BASE = 10 ** 5;

    address public override immutable whitelistFactory;
    address public override immutable pairCreator;
    address public override immutable configStore;

    uint256 public override tradeFee;
    uint256 public override protocolFee;
    address public override protocolFeeTo;

    mapping(address => mapping(address => address[])) public override getPair;
    mapping(address => uint256) public override pairIdx;
    address[] public override allPairs;

    address public override restrictedLiquidityProvider;
    mapping (address => mapping (address => address)) public override oracles;
    mapping (address => bool) public override isOracle;

    constructor(address _governance, address _whitelistFactory, address _pairCreator, address _configStore, uint256 _tradeFee, uint256 _protocolFee, address _protocolFeeTo) OSWAP_PausableFactory(_governance) public {
        whitelistFactory = _whitelistFactory;
        pairCreator = _pairCreator;
        configStore = _configStore;
        tradeFee = _tradeFee;
        protocolFee = _protocolFee;
        protocolFeeTo = _protocolFeeTo;
    }
    // only set at deployment time
    function init(address _restrictedLiquidityProvider) external override onlyOwner {
        require(restrictedLiquidityProvider == address(0), "RestrictedLiquidityProvider already set");
        restrictedLiquidityProvider = _restrictedLiquidityProvider;
    }

    function getCreateAddresses() external override view returns (address _governance, address _whitelistFactory, address _restrictedLiquidityProvider, address _configStore) {
        return (governance, whitelistFactory, restrictedLiquidityProvider, configStore);
    }

    function pairLength(address tokenA, address tokenB) external override view returns (uint256) {
        return getPair[tokenA][tokenB].length;
    }
    function allPairsLength() external override view returns (uint) {
        return allPairs.length;
    }

    // support multiple pairs
    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'ZERO_ADDRESS');

        bytes32 salt = keccak256(abi.encodePacked(token0, token1, getPair[token0][token1].length));
        // bytes4(keccak256(bytes('createPair(bytes32)')));
        (bool success, bytes memory data) = pairCreator.delegatecall(abi.encodeWithSelector(0xED25A5A2, salt));
        require(success, "Failed to create pair");
        (pair) = abi.decode(data, (address));
        IOSWAP_PairBase(pair).initialize(token0, token1);

        getPair[token0][token1].push(pair);
        getPair[token1][token0].push(pair); // populate mapping in the reverse direction
        pairIdx[pair] = allPairs.length;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, getPair[token0][token1].length, allPairs.length);
    }

    // add new oracle not seen before or update an oracle for an existing pair
    function setOracle(address tokenA, address tokenB, address oracle) external override {
        changeOracle(tokenA, tokenB, oracle);
    }
    // add existing/already seen oracle to new pair with lower quorum
    function addOldOracleToNewPair(address tokenA, address tokenB, address oracle) external override {
        require(oracles[tokenA][tokenB] == address(0), "oracle already set");
        require(isOracle[oracle], "oracle not seen");
        changeOracle(tokenA, tokenB, oracle);
    }
    function changeOracle(address tokenA, address tokenB, address oracle) private onlyVoting {
        require(tokenA < tokenB, "Invalid address pair order");
        require(IOSWAP_OracleAdaptor2(oracle).isSupported(tokenA, tokenB), "Pair not supported by oracle");
        oracles[tokenA][tokenB] = oracle;
        oracles[tokenB][tokenA] = oracle;
        isOracle[oracle] = true;
        emit OracleAdded(tokenA, tokenB, oracle);
    }

    function isPair(address pair) external override view returns (bool) {
        return allPairs.length != 0 && allPairs[pairIdx[pair]] == pair;
    }

    function setTradeFee(uint256 _tradeFee) external override onlyVoting {
        require(_tradeFee <= FEE_BASE, "INVALID_TRADE_FEE");
        tradeFee = _tradeFee;
        emit ParamSet("tradeFee", bytes32(tradeFee));
    }
    function setProtocolFee(uint256 _protocolFee) external override onlyVoting {
        require(_protocolFee <= FEE_BASE, "INVALID_PROTOCOL_FEE");
        protocolFee = _protocolFee;
        emit ParamSet("protocolFee", bytes32(protocolFee));
    }
    function setProtocolFeeTo(address _protocolFeeTo) external override onlyVoting {
        protocolFeeTo = _protocolFeeTo;
        emit ParamSet("protocolFeeTo", bytes32(bytes20(protocolFeeTo)));
    }

    function checkAndGetOracleSwapParams(address tokenA, address tokenB) external view override returns (address oracle_, uint256 tradeFee_, uint256 protocolFee_) {
        require(isLive, 'GLOBALLY PAUSED');
        address oracle = checkAndGetOracle(tokenA, tokenB);
        return (oracle, tradeFee, protocolFee);
    }
    function checkAndGetOracle(address tokenA, address tokenB) public view override returns (address oracle) {
        require(tokenA < tokenB, 'Address must be sorted');
        oracle = oracles[tokenA][tokenB];
        require(oracle != address(0), 'No oracle found');
        // FIXME:
        // uint256 score = oracleScores[oracle];
        // require(score >= minOracleScore, 'Oracle score too low');
    }
}