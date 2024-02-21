// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import {Admin} from "../../abstract/Admin.sol";
import {Initializable} from "../../abstract/Initializable.sol";

import {IDropsPriceOracle} from "../interface/IDropsPriceOracle.sol";
import {IUniswapV2Pair} from "./interface/IUniswapV2Pair.sol";

contract DropsPriceOracleArbitrumNova is Admin, Initializable, IDropsPriceOracle {
  address constant WETH = 0x0000000000000000000000000000000000000000; // 18 decimals
  address constant USDC = 0x0000000000000000000000000000000000000000; // 6 decimals
  address constant USDT = 0x0000000000000000000000000000000000000000; // 6 decimals

  IUniswapV2Pair constant SushiV2UsdcPool = IUniswapV2Pair(0x0000000000000000000000000000000000000000);
  IUniswapV2Pair constant SushiV2UsdtPool = IUniswapV2Pair(0x0000000000000000000000000000000000000000);

  IUniswapV2Pair constant UniV2UsdcPool = IUniswapV2Pair(0x0000000000000000000000000000000000000000);
  IUniswapV2Pair constant UniV2UsdtPool = IUniswapV2Pair(0x0000000000000000000000000000000000000000);

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
  function convertUsdToWei(uint256 usdAmount) external view returns (uint256 weiAmount) {
    weiAmount =
      (_getSushiUSDC(usdAmount) + _getSushiUSDT(usdAmount) + _getUniUSDC(usdAmount) + _getUniUSDT(usdAmount)) /
      4;
  }

  function _getSushiUSDC(uint256 usdAmount) internal view returns (uint256 weiAmount) {
    // add decimal places for amount IF decimals are above 6!
    // usdAmount = usdAmount * (10**(18 - 6));
    (uint112 _reserve0, uint112 _reserve1, ) = SushiV2UsdcPool.getReserves();
    // x is always native token / WETH
    uint256 x = _reserve1;
    // y is always USD token / USDC
    uint256 y = _reserve0;

    uint256 numerator = (x * usdAmount) * 1000;
    uint256 denominator = (y - usdAmount) * 997;

    weiAmount = (numerator / denominator) + 1;
  }

  function _getSushiUSDT(uint256 usdAmount) internal view returns (uint256 weiAmount) {
    // add decimal places for amount IF decimals are above 6!
    // usdAmount = usdAmount * (10**(18 - 6));
    (uint112 _reserve0, uint112 _reserve1, ) = SushiV2UsdtPool.getReserves();
    // x is always native token / WETH
    uint256 x = _reserve0;
    // y is always USD token / USDT
    uint256 y = _reserve1;

    uint256 numerator = (x * usdAmount) * 1000;
    uint256 denominator = (y - usdAmount) * 997;

    weiAmount = (numerator / denominator) + 1;
  }

  function _getUniUSDC(uint256 usdAmount) internal view returns (uint256 weiAmount) {
    // add decimal places for amount IF decimals are above 6!
    // usdAmount = usdAmount * (10**(18 - 6));
    (uint112 _reserve0, uint112 _reserve1, ) = UniV2UsdcPool.getReserves();
    // x is always native token / WETH
    uint256 x = _reserve1;
    // y is always USD token / USDC
    uint256 y = _reserve0;

    uint256 numerator = (x * usdAmount) * 1000;
    uint256 denominator = (y - usdAmount) * 997;

    weiAmount = (numerator / denominator) + 1;
  }

  function _getUniUSDT(uint256 usdAmount) internal view returns (uint256 weiAmount) {
    // add decimal places for amount IF decimals are above 6!
    // usdAmount = usdAmount * (10**(18 - 6));
    (uint112 _reserve0, uint112 _reserve1, ) = UniV2UsdtPool.getReserves();
    // x is always native token / WETH
    uint256 x = _reserve0;
    // y is always USD token / USDT
    uint256 y = _reserve1;

    uint256 numerator = (x * usdAmount) * 1000;
    uint256 denominator = (y - usdAmount) * 997;

    weiAmount = (numerator / denominator) + 1;
  }
}
