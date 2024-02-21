// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import {Admin} from "../../abstract/Admin.sol";
import {Initializable} from "../../abstract/Initializable.sol";

import {IDropsPriceOracle} from "../interface/IDropsPriceOracle.sol";

contract DropsPriceOracleBaseTestnetGoerli is Admin, Initializable, IDropsPriceOracle {
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.tokenPriceRatio')) - 1)
   */
  bytes32 constant _tokenPriceRatioSlot = 0x562ce994878444f1ca8bcf3afcea513b950965abed659462312e8fdd38c020a1;

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
      sstore(_tokenPriceRatioSlot, 0x0000000000000000000000000000000000000000000000d8d726b7177a800000)
    }
    _setInitialized();
    return Initializable.init.selector;
  }

  /**
   * @notice Convert USD value to native gas token value
   * @param usdAmount a 6 decimal places USD amount
   */
  function convertUsdToWei(uint256 usdAmount) external view returns (uint256 weiAmount) {
    // USD is with 6 decimal places
    // WETH  is with 18 decimal places
    // we add decimal places for USD to match WETH  decimals
    usdAmount = usdAmount * (10 ** (18 - 6));
    // x is always native token / WETH
    // we use precision of 21
    uint256 x = 1000000000000000000 * (10 ** 21);
    // y is always USD token / USDC
    // load token price ratio
    uint256 tokenPriceRatio;
    assembly {
      tokenPriceRatio := sload(_tokenPriceRatioSlot)
    }
    // in our case, we use ratio for defining USD cost of 1 WETH
    // we use precision of 21
    uint256 y = tokenPriceRatio * (10 ** 21);

    uint256 numerator = x * usdAmount;
    uint256 denominator = y - usdAmount;

    weiAmount = (numerator / denominator) + 1;
  }

  function getTokenPriceRatio() external view returns (uint256 tokenPriceRatio) {
    assembly {
      tokenPriceRatio := sload(_tokenPriceRatioSlot)
    }
  }

  function setTokenPriceRatio(uint256 tokenPriceRatio) external onlyAdmin {
    assembly {
      sstore(_tokenPriceRatioSlot, tokenPriceRatio)
    }
  }
}
