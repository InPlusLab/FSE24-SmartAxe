// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import {Admin} from "../../abstract/Admin.sol";
import {Initializable} from "../../abstract/Initializable.sol";

import {IDropsPriceOracle} from "../interface/IDropsPriceOracle.sol";
import {IUniswapV2Pair} from "./interface/IUniswapV2Pair.sol";

contract DropsPriceOracleEthereum is Admin, Initializable, IDropsPriceOracle {
  address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // 18 decimals
  address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // 6 decimals
  address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // 6 decimals

  IUniswapV2Pair constant SushiV2UsdcPool = IUniswapV2Pair(0x397FF1542f962076d0BFE58eA045FfA2d347ACa0);
  IUniswapV2Pair constant SushiV2UsdtPool = IUniswapV2Pair(0x06da0fd433C1A5d7a4faa01111c044910A184553);

  IUniswapV2Pair constant UniV2UsdcPool = IUniswapV2Pair(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);
  IUniswapV2Pair constant UniV2UsdtPool = IUniswapV2Pair(0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852);

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
