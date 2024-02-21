// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import {Admin} from "../../abstract/Admin.sol";
import {Initializable} from "../../abstract/Initializable.sol";

import {IDropsPriceOracle} from "../interface/IDropsPriceOracle.sol";

contract DropsPriceOracleZoraTestnetGoerli is Admin, Initializable, IDropsPriceOracle {
  /**
   * @dev Constructor is left empty and init is used instead
   */
  constructor() {}

  /**
   * @notice Used internally to initialize the contract instead of through a constructor
   * @dev This function is called by the deployer/factory when creating a contract
   */
  function init(bytes memory) external override returns (bytes4) {
    require(!_isInitialized(), "HOLOGRAPH: already initialized");
    assembly {
      sstore(_adminSlot, origin())
    }
    _setInitialized();
    return Initializable.init.selector;
  }

  /**
   * @notice Convert USD value to native gas token value
   * @dev It is important to note that different USD stablecoins use different decimal places.
   * @param usdAmount a 6 decimal places USD amount
   */
  function convertUsdToWei(uint256 usdAmount) external pure returns (uint256 weiAmount) {
    weiAmount = (_getUSDC(usdAmount) + _getUSDT(usdAmount)) / 2;
  }

  function _getUSDC(uint256 usdAmount) internal pure returns (uint256 weiAmount) {
    // add decimal places for amount IF decimals are above 6!
    // usdAmount = usdAmount * (10**(18 - 6));
    // (uint112 _reserve0, uint112 _reserve1,) = SushiV2UsdcPool.getReserves();
    uint112 _reserve0 = 185186616552407552407157;
    uint112 _reserve1 = 207981749778;
    // x is always native token / WMATIC
    uint256 x = _reserve0;
    // y is always USD token / USDC
    uint256 y = _reserve1;

    uint256 numerator = (x * usdAmount) * 1000;
    uint256 denominator = (y - usdAmount) * 997;

    weiAmount = (numerator / denominator) + 1;
  }

  function _getUSDT(uint256 usdAmount) internal pure returns (uint256 weiAmount) {
    // add decimal places for amount IF decimals are above 6!
    // usdAmount = usdAmount * (10**(18 - 6));
    // (uint112 _reserve0, uint112 _reserve1,) = SushiV2UsdtPool.getReserves();
    uint112 _reserve0 = 13799757434002573084810;
    uint112 _reserve1 = 15484391886;
    // x is always native token / WMATIC
    uint256 x = _reserve0;
    // y is always USD token / USDT
    uint256 y = _reserve1;

    uint256 numerator = (x * usdAmount) * 1000;
    uint256 denominator = (y - usdAmount) * 997;

    weiAmount = (numerator / denominator) + 1;
  }
}
