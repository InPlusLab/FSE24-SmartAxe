// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../commons/OSWAP_FactoryBase.sol';
import './interfaces/IOSWAP_OracleFactory.sol';
import './interfaces/IOSWAP_OracleScoreOracleAdaptor.sol';
import './interfaces/IOSWAP_OracleAdaptor.sol';
import '../libraries/Ownable.sol';

contract OSWAP_OracleFactory is OSWAP_FactoryBase, IOSWAP_OracleFactory, Ownable { 

    uint256 constant FEE_BASE = 10 ** 5;

    address public override oracleLiquidityProvider;

    uint256 public override tradeFee;
    uint256 public override protocolFee;
    uint256 public override feePerDelegator;
    address public override protocolFeeTo;

    address public override securityScoreOracle;
    uint256 public override minOracleScore;

    // Oracle
    mapping (address => mapping (address => address)) public override oracles;
    mapping (address => uint256) public override minLotSize;
    mapping (address => bool) public override isOracle;
    mapping (address => uint256) public override oracleScores;

    address[] public override whitelisted;
    mapping (address => uint256) public override whitelistedInv;
    mapping (address => bool) public override isWhitelisted; 

    constructor(address _governance, address _pairCreator, uint256 _tradeFee, uint256 _protocolFee, uint256 _feePerDelegator, address _protocolFeeTo) public 
        OSWAP_FactoryBase(_governance, _pairCreator)
    {
        require(_tradeFee <= FEE_BASE, "INVALID_TRADE_FEE");
        require(_protocolFee <= FEE_BASE, "INVALID_PROTOCOL_FEE");

        tradeFee = _tradeFee;
        protocolFee = _protocolFee;
        feePerDelegator = _feePerDelegator;
        protocolFeeTo = _protocolFeeTo;

        emit ParamSet("tradeFee", bytes32(tradeFee));
        emit ParamSet("protocolFee", bytes32(protocolFee));
        emit ParamSet("feePerDelegator", bytes32(feePerDelegator));
        emit ParamSet("protocolFeeTo", bytes32(bytes20(protocolFeeTo)));
    }
    // only set at deployment time
    function setOracleLiquidityProvider(address _oracleRouter, address _oracleLiquidityProvider) external override onlyOwner {
        require(oracleLiquidityProvider == address(0), "OracleLiquidityProvider already set");
        oracleLiquidityProvider = _oracleLiquidityProvider;

        if (whitelisted.length==0 || whitelisted[whitelistedInv[_oracleRouter]] != _oracleRouter) {
            whitelistedInv[_oracleRouter] = whitelisted.length; 
            whitelisted.push(_oracleRouter);
        }
        isWhitelisted[_oracleRouter] = true;
        emit Whitelisted(_oracleRouter, true);        
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
        require(IOSWAP_OracleAdaptor(oracle).isSupported(tokenA, tokenB), "Pair not supported by oracle");
        oracles[tokenA][tokenB] = oracle;
        oracles[tokenB][tokenA] = oracle;
        isOracle[oracle] = true;
        emit OracleAdded(tokenA, tokenB, oracle);
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
    function setFeePerDelegator(uint256 _feePerDelegator) external override onlyVoting {
        feePerDelegator = _feePerDelegator;
        emit ParamSet("feePerDelegator", bytes32(feePerDelegator));
    }
    function setProtocolFeeTo(address _protocolFeeTo) external override onlyVoting {
        protocolFeeTo = _protocolFeeTo;
        emit ParamSet("protocolFeeTo", bytes32(bytes20(protocolFeeTo)));
    }
    function setSecurityScoreOracle(address _securityScoreOracle, uint256 _minOracleScore) external override onlyVoting {
        require(_minOracleScore <= 100, "Invalid security score");
        securityScoreOracle = _securityScoreOracle;
        minOracleScore = _minOracleScore;
        emit ParamSet2("securityScoreOracle", bytes32(bytes20(securityScoreOracle)), bytes32(minOracleScore));
    }
    function setMinLotSize(address token, uint256 _minLotSize) external override onlyVoting {
        minLotSize[token] = _minLotSize;
        emit ParamSet2("minLotSize", bytes32(bytes20(token)), bytes32(_minLotSize));
    }

    function updateOracleScore(address oracle) external override {
        require(isOracle[oracle], "Oracle Adaptor not found");
        uint256 score = IOSWAP_OracleScoreOracleAdaptor(securityScoreOracle).getSecurityScore(oracle);
        oracleScores[oracle] = score;
        emit OracleScores(oracle, score);
    }

    function whitelistedLength() external view override returns (uint256) {
        return whitelisted.length;
    }
    function allWhiteListed() external view override returns(address[] memory list, bool[] memory allowed) {
        list = whitelisted;
        uint256 length = list.length;
        allowed = new bool[](length);
        for (uint256 i = 0 ; i < length ; i++) {
            allowed[i] = isWhitelisted[whitelisted[i]];
        }
    }
    function setWhiteList(address _who, bool _allow) external override onlyVoting {
        if (whitelisted.length==0 || whitelisted[whitelistedInv[_who]] != _who) {
            whitelistedInv[_who] = whitelisted.length; 
            whitelisted.push(_who);
        }
        isWhitelisted[_who] = _allow;
        emit Whitelisted(_who, _allow);
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
        uint256 score = oracleScores[oracle];
        require(score >= minOracleScore, 'Oracle score too low');
    }
}
