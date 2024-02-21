// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './interfaces/IOSWAP_OracleScoreOracleAdaptor.sol';
import './interfaces/ICertiKSecurityOracle.sol';

contract OSWAP_CertiKSecurityOracle is IOSWAP_OracleScoreOracleAdaptor {
    address public override immutable oracleAddress;

    constructor(address _oracleAddress) public {
        require(_oracleAddress != address(0), "Invalid oracle address");
        oracleAddress = _oracleAddress;
    }

    function getSecurityScore(address oracle) external view override returns (uint) {
        return ICertiKSecurityOracle(oracleAddress).getSecurityScore(oracle);
    }
}
