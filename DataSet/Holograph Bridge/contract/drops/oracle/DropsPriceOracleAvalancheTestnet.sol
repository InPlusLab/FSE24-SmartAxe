// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import {Admin} from "../../abstract/Admin.sol";
import {Initializable} from "../../abstract/Initializable.sol";

import {IDropsPriceOracle} from "../interface/IDropsPriceOracle.sol";
import {IUniswapV2Pair} from "./interface/IUniswapV2Pair.sol";

contract DropsPriceOracleAvalancheTestnet is Admin, Initializable, IDropsPriceOracle {
  address constant WAVAX = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c;
  address constant USDC = 0x5425890298aed601595a70AB815c96711a31Bc65; // 6 decimals
  address constant USDT = 0x0000000000000000000000000000000000000000; // 6 decimals

  IUniswapV2Pair constant SushiV2UsdcPool = IUniswapV2Pair(0x1B92bf7394d317A758d953F6428445A8977e195C);
  IUniswapV2Pair constant SushiV2UsdtPool = IUniswapV2Pair(0x0000000000000000000000000000000000000000);

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
    weiAmount = (_getSushiUSDC(usdAmount) + _getSushiUSDT(usdAmount)) / 2;
  }

  function _getSushiUSDC(uint256 usdAmount) internal pure returns (uint256 weiAmount) {
    // add decimal places for amount IF decimals are above 6!
    // usdAmount = usdAmount * (10**(18 - 6));
    // (uint112 _reserve0, uint112 _reserve1,) = SushiV2UsdcPool.getReserves();
    uint112 _reserve0 = 133224784402692878349;
    uint112 _reserve1 = 2205199060;
    // x is always native token / WAVAX
    uint256 x = _reserve0;
    // y is always USD token / USDC
    uint256 y = _reserve1;

    uint256 numerator = (x * usdAmount) * 1000;
    uint256 denominator = (y - usdAmount) * 997;

    weiAmount = (numerator / denominator) + 1;
  }

  function _getSushiUSDT(uint256 usdAmount) internal pure returns (uint256 weiAmount) {
    // add decimal places for amount IF decimals are above 6!
    // usdAmount = usdAmount * (10**(18 - 6));
    // (uint112 _reserve0, uint112 _reserve1,) = SushiV2UsdtPool.getReserves();
    uint112 _reserve0 = 2205199060;
    uint112 _reserve1 = 133224784402692878349;
    // x is always native token / WAVAX
    uint256 x = _reserve1;
    // y is always USD token / USDT
    uint256 y = _reserve0;

    uint256 numerator = (x * usdAmount) * 1000;
    uint256 denominator = (y - usdAmount) * 997;

    weiAmount = (numerator / denominator) + 1;
  }
}
