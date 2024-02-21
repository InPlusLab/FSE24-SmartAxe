// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import "../../commons/interfaces/IOSWAP_FactoryBase.sol";

interface IOSWAP_Factory is IOSWAP_FactoryBase {
    event ParamSet(bytes32 name, bytes32 value);
    event ParamSet2(bytes32 name, bytes32 value1, bytes32 value2);

    function tradeFee() external view returns (uint256);
    function protocolFee() external view returns (uint256);
    function protocolFeeTo() external view returns (address);

    function protocolFeeParams() external view returns (uint256 _protocolFee, address _protocolFeeTo);

    function setTradeFee(uint256) external;
    function setProtocolFee(uint256) external;
    function setProtocolFeeTo(address) external;
}
