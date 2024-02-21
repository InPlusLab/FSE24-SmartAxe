// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../libraries/SafeMath.sol';
import "../oracle/interfaces/IOSWAP_OracleAdaptor2.sol";
import "./interfaces/IOSWAP_RestrictedPair.sol";
// import "./interfaces/IOSWAP_ConfigStore.sol";

contract OSWAP_RestrictedPairOracle is IOSWAP_OracleAdaptor2 {
    using SafeMath for uint;

    uint256 public constant WEI = 10**18;

    // address public immutable configStore;

    constructor(/*address _configStore*/) public {
        // configStore = _configStore;
    }

    function isSupported(address /*from*/, address /*to*/) external override view returns (bool supported) {
        return true;
    }
    function getRatio(address from, address to, uint256 /*fromAmount*/, uint256 /*toAmount*/, address /*trader*/, bytes memory payload) external override view returns (uint256 numerator, uint256 denominator) {
        bool direction = from < to;

        IOSWAP_RestrictedPair pair = IOSWAP_RestrictedPair(msg.sender);

        uint256 index;
        assembly {
            index := mload(add(payload, 0x20))
        }

        (/*address provider*/,/*bool locked*/,/*uint256 feePaid*/,/*uint256 amount*/,/*uint256 receiving*/,uint256 restrictedPrice,/*uint256 startDate*/,/*uint256 expire*/) = pair.offers(direction, index);
        return (restrictedPrice, WEI);
    }
    function getLatestPrice(address from, address to, bytes memory payload) external override view returns (uint256 price) {
        IOSWAP_RestrictedPair pair = IOSWAP_RestrictedPair(msg.sender);
        uint256 index;
        assembly {
            index := mload(add(payload, 0x20))
        }

        bool direction = from < to;
        (/*address provider*/,/*bool locked*/,/*uint256 feePaid*/,/*uint256 amount*/,/*uint256 receiving*/,price,/*uint256 startDate*/,/*uint256 expire*/) = pair.offers(direction, index);
    }
    function decimals() external override view returns (uint8) {
        return 18;
    }
}