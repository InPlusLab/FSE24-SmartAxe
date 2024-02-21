// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import {Admin} from "../../abstract/Admin.sol";
import {Initializable} from "../../abstract/Initializable.sol";

import {IDropsPriceOracle} from "../interface/IDropsPriceOracle.sol";
import {IUniswapV2Pair} from "./interface/IUniswapV2Pair.sol";

contract DropsPriceOracleBinanceSmartChain is Admin, Initializable, IDropsPriceOracle {
  address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
  address constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d; // 18 decimals
  address constant USDT = 0x55d398326f99059fF775485246999027B3197955; // 18 decimals
  address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; // 18 decimals

  IUniswapV2Pair constant SushiV2UsdcPool = IUniswapV2Pair(0xc7632B7b2d768bbb30a404E13E1dE48d1439ec21);
  IUniswapV2Pair constant SushiV2UsdtPool = IUniswapV2Pair(0x2905817b020fD35D9d09672946362b62766f0d69);
  IUniswapV2Pair constant SushiV2BusdPool = IUniswapV2Pair(0xDc558D64c29721d74C4456CfB4363a6e6660A9Bb);

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
    weiAmount = (_getUSDC(usdAmount) + _getUSDT(usdAmount) + _getBUSD(usdAmount)) / 3;
  }

  function _getUSDC(uint256 usdAmount) internal view returns (uint256 weiAmount) {
    // add decimal places for amount IF decimals are above 6!
    usdAmount = usdAmount * (10 ** (18 - 6));
    (uint112 _reserve0, uint112 _reserve1, ) = SushiV2UsdcPool.getReserves();
    // x is always native token / WBNB
    uint256 x = _reserve1;
    // y is always USD token / USDC
    uint256 y = _reserve0;

    uint256 numerator = (x * usdAmount) * 1000;
    uint256 denominator = (y - usdAmount) * 997;

    weiAmount = (numerator / denominator) + 1;
  }

  function _getUSDT(uint256 usdAmount) internal view returns (uint256 weiAmount) {
    // add decimal places for amount IF decimals are above 6!
    usdAmount = usdAmount * (10 ** (18 - 6));
    (uint112 _reserve0, uint112 _reserve1, ) = SushiV2UsdtPool.getReserves();
    // x is always native token / WBNB
    uint256 x = _reserve1;
    // y is always USD token / USDT
    uint256 y = _reserve0;

    uint256 numerator = (x * usdAmount) * 1000;
    uint256 denominator = (y - usdAmount) * 997;

    weiAmount = (numerator / denominator) + 1;
  }

  function _getBUSD(uint256 usdAmount) internal view returns (uint256 weiAmount) {
    // add decimal places for amount IF decimals are above 6!
    usdAmount = usdAmount * (10 ** (18 - 6));
    (uint112 _reserve0, uint112 _reserve1, ) = SushiV2BusdPool.getReserves();
    // x is always native token / WBNB
    uint256 x = _reserve0;
    // y is always USD token / BUSD
    uint256 y = _reserve1;

    uint256 numerator = (x * usdAmount) * 1000;
    uint256 denominator = (y - usdAmount) * 997;

    weiAmount = (numerator / denominator) + 1;
  }
}
