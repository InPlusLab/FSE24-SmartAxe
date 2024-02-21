// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../commons/OSWAP_FactoryBase.sol';
import './interfaces/IOSWAP_RangeFactory.sol';
import '../libraries/Ownable.sol';

contract OSWAP_RangeFactory is OSWAP_FactoryBase, IOSWAP_RangeFactory, Ownable { 

    uint256 constant FEE_BASE = 10 ** 5;

    address public override immutable oracleFactory;
    address public override rangeLiquidityProvider;

    uint256 public override tradeFee;
    uint256[] public override stakeAmount;
    uint256[] public override liquidityProviderShare;
    address public override protocolFeeTo;

    constructor(address _governance, address _oracleFactory, address _pairCreator, uint256 _tradeFee, uint256[] memory _stakeAmount, uint256[] memory _liquidityProviderShare, address _protocolFeeTo) public 
        OSWAP_FactoryBase(_governance, _pairCreator)
    {
        oracleFactory = _oracleFactory;
        _setTradeFee(_tradeFee);
        _setLiquidityProviderShare(_stakeAmount, _liquidityProviderShare);
        _setProtocolFeeTo(_protocolFeeTo);
    }
    // only set at deployment time
    function setRangeLiquidityProvider(address _rangeLiquidityProvider) external override onlyOwner {
        require(rangeLiquidityProvider == address(0), "RangeLiquidityProvider already set");
        rangeLiquidityProvider = _rangeLiquidityProvider;
    }

    function getCreateAddresses() external override view returns (address _governance, address _rangeLiquidityProvider, address _oracleFactory) {
        return (governance, rangeLiquidityProvider, oracleFactory);
    }

    function setTradeFee(uint256 _tradeFee) external override onlyVoting {
        _setTradeFee(_tradeFee);
    }
    function _setTradeFee(uint256 _tradeFee) internal {
        require(_tradeFee <= FEE_BASE, "INVALID_TRADE_FEE");
        tradeFee = _tradeFee;
        emit ParamSet("tradeFee", bytes32(tradeFee));
    }
    function setLiquidityProviderShare(uint256[] calldata _stakeAmount, uint256[] calldata _liquidityProviderShare) external override onlyVoting {
        _setLiquidityProviderShare(_stakeAmount, _liquidityProviderShare);
    }
    function _setLiquidityProviderShare(uint256[] memory _stakeAmount, uint256[] memory _liquidityProviderShare) internal {
        uint256 length = _stakeAmount.length;
        require(length == _liquidityProviderShare.length, "LENGTH NOT MATCH");
        stakeAmount = _stakeAmount;
        liquidityProviderShare = _liquidityProviderShare;
        for (uint256 i = 0 ; i < length ; i++) {
            require(_liquidityProviderShare[i] <= FEE_BASE, "INVALID LIQUIDITY SHARE");
            if (i > 0){
                require(_stakeAmount[i-1] < _stakeAmount[i], "STAKE AMOUNT NOT IN ASCENDING ORDER");
            }
            emit ParamSet2("liquidityProviderShare", bytes32(_stakeAmount[i]), bytes32(_liquidityProviderShare[i]));
        }
    }
    function getAllLiquidityProviderShare() external view override returns (uint256[] memory _stakeAmount, uint256[] memory _liquidityProviderShare) {
        return (stakeAmount, liquidityProviderShare);
    }
    function getLiquidityProviderShare(uint256 stake) external view override returns (uint256 _liquidityProviderShare) {
        uint256 length = stakeAmount.length;
        for (uint256 i = length - 1 ; i < length ; i--) {
            if (stakeAmount[i] <= stake) {
                return liquidityProviderShare[i];
            }
        }
    }

    function setProtocolFeeTo(address _protocolFeeTo) external override onlyVoting {
        _setProtocolFeeTo(_protocolFeeTo);
    }
    function _setProtocolFeeTo(address _protocolFeeTo) internal {
        protocolFeeTo = _protocolFeeTo;
        emit ParamSet("protocolFeeTo", bytes32(bytes20(protocolFeeTo)));
    }

    function checkAndGetSwapParams() external view override returns (uint256 _tradeFee) {
        require(isLive, 'GLOBALLY PAUSED');
        _tradeFee = tradeFee;   
    }
}
