// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import "../../commons/interfaces/IOSWAP_FactoryBase.sol";

interface IOSWAP_RangeFactory is IOSWAP_FactoryBase {
    event ParamSet(bytes32 name, bytes32 value);
    event ParamSet2(bytes32 name, bytes32 value1, bytes32 value2);

    function oracleFactory() external view returns (address);
    function rangeLiquidityProvider() external view returns (address);

    function getCreateAddresses() external view returns (address _governance, address _rangeLiquidityProvider, address _oracleFactory);
    function tradeFee() external view returns (uint256);
    function stakeAmount(uint256) external view returns (uint256);
    function liquidityProviderShare(uint256) external view returns (uint256);
    function protocolFeeTo() external view returns (address);

    function setRangeLiquidityProvider(address _rangeLiquidityProvider) external;

    function setTradeFee(uint256) external;
    function setLiquidityProviderShare(uint256[] calldata, uint256[] calldata) external;
    function getAllLiquidityProviderShare() external view returns (uint256[] memory _stakeAmount, uint256[] memory _liquidityProviderShare);
    function getLiquidityProviderShare(uint256 stake) external view returns (uint256 _liquidityProviderShare);
    function setProtocolFeeTo(address) external;

    function checkAndGetSwapParams() external view returns (uint256 _tradeFee);
}
