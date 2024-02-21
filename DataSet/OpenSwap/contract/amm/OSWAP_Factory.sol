// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../commons/OSWAP_FactoryBase.sol';
import './interfaces/IOSWAP_Factory.sol';

contract OSWAP_Factory is OSWAP_FactoryBase, IOSWAP_Factory {

    uint256 constant FEE_BASE = 10 ** 5;

    uint256 public override tradeFee;
    uint256 public override protocolFee;
    address public override protocolFeeTo;

    constructor(address _governance, address _pairCreator, uint256 _tradeFee, uint256 _protocolFee, address _protocolFeeTo) public 
        OSWAP_FactoryBase(_governance, _pairCreator)
    {
        require(_tradeFee <= FEE_BASE, "INVALID_TRADE_FEE");
        require(_protocolFee <= FEE_BASE, "INVALID_PROTOCOL_FEE");

        tradeFee = _tradeFee;
        protocolFee = _protocolFee;
        protocolFeeTo = _protocolFeeTo;

        emit ParamSet("tradeFee", bytes32(tradeFee));
        emit ParamSet("protocolFee", bytes32(protocolFee));
        emit ParamSet("protocolFeeTo", bytes32(bytes20(protocolFeeTo)));
    }

    function protocolFeeParams() external override view returns (uint256 _protocolFee, address _protocolFeeTo) {
        return (protocolFee, protocolFeeTo);
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
}
