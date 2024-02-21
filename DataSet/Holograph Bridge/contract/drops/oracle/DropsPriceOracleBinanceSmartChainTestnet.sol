// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import {Admin} from "../../abstract/Admin.sol";
import {Initializable} from "../../abstract/Initializable.sol";

import {IDropsPriceOracle} from "../interface/IDropsPriceOracle.sol";
import {IUniswapV2Pair} from "./interface/IUniswapV2Pair.sol";

contract DropsPriceOracleBinanceSmartChainTestnet is Admin, Initializable, IDropsPriceOracle {
  address constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
  address constant USDC = 0x0000000000000000000000000000000000000000; // 18 decimals
  address constant USDT = 0x337610d27c682E347C9cD60BD4b3b107C9d34dDd; // 18 decimals
  address constant BUSD = 0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee; // 18 decimals

  IUniswapV2Pair constant SushiV2UsdcPool = IUniswapV2Pair(0x0000000000000000000000000000000000000000);
  IUniswapV2Pair constant SushiV2UsdtPool = IUniswapV2Pair(0x622A814A1c842D34F9828370d9015Dc9d4c5b6F1);
  IUniswapV2Pair constant SushiV2BusdPool = IUniswapV2Pair(0x9A0eeceDA5c0203924484F5467cEE4321cf6A189);

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
    weiAmount = (_getUSDC(usdAmount) + _getUSDT(usdAmount) + _getBUSD(usdAmount)) / 3;
  }

  function _getUSDC(uint256 usdAmount) internal pure returns (uint256 weiAmount) {
    // add decimal places for amount IF decimals are above 6!
    usdAmount = usdAmount * (10 ** (18 - 6));
    // (uint112 _reserve0, uint112 _reserve1,) = SushiV2UsdcPool.getReserves();
    uint112 _reserve0 = 13021882855694508203763;
    uint112 _reserve1 = 40694382259814793835;
    // x is always native token / WBNB
    uint256 x = _reserve1;
    // y is always USD token / USDC
    uint256 y = _reserve0;

    uint256 numerator = (x * usdAmount) * 1000;
    uint256 denominator = (y - usdAmount) * 997;

    weiAmount = (numerator / denominator) + 1;
  }

  function _getUSDT(uint256 usdAmount) internal pure returns (uint256 weiAmount) {
    // add decimal places for amount IF decimals are above 6!
    usdAmount = usdAmount * (10 ** (18 - 6));
    // (uint112 _reserve0, uint112 _reserve1,) = SushiV2UsdtPool.getReserves();
    uint112 _reserve0 = 27194218672878436248359;
    uint112 _reserve1 = 85236077287017749564;
    // x is always native token / WBNB
    uint256 x = _reserve1;
    // y is always USD token / USDT
    uint256 y = _reserve0;

    uint256 numerator = (x * usdAmount) * 1000;
    uint256 denominator = (y - usdAmount) * 997;

    weiAmount = (numerator / denominator) + 1;
  }

  function _getBUSD(uint256 usdAmount) internal pure returns (uint256 weiAmount) {
    // add decimal places for amount IF decimals are above 6!
    usdAmount = usdAmount * (10 ** (18 - 6));
    // (uint112 _reserve0, uint112 _reserve1,) = SushiV2BusdPool.getReserves();
    uint112 _reserve0 = 18888866298338593382;
    uint112 _reserve1 = 6055244885106491861952;
    // x is always native token / WBNB
    uint256 x = _reserve0;
    // y is always USD token / BUSD
    uint256 y = _reserve1;

    uint256 numerator = (x * usdAmount) * 1000;
    uint256 denominator = (y - usdAmount) * 997;

    weiAmount = (numerator / denominator) + 1;
  }
}
