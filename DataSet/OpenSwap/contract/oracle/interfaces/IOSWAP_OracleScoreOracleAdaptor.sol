// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

interface IOSWAP_OracleScoreOracleAdaptor {
    function oracleAddress() external view returns (address);
    function getSecurityScore(address oracle) external view returns (uint);
}
