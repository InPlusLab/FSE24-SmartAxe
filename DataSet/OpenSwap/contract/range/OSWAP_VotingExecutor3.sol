// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../gov/interfaces/IOAXDEX_VotingExecutor.sol';
import './interfaces/IOSWAP_RangeFactory.sol';
import '../gov/interfaces/IOAXDEX_Governance.sol';
import '../router/interfaces/IOSWAP_HybridRouterRegistry.sol';

contract OSWAP_VotingExecutor3 is IOAXDEX_VotingExecutor {

    address public immutable governance;
    address public immutable factory;
    address public immutable hybridRegistry;

    constructor(address _governance, address _factory, address _hybridRegistry) public {
        factory = _factory;
        governance = _governance;//IOSWAP_RangeFactory(_factory).governance();
        hybridRegistry = _hybridRegistry;
    }

    function execute(bytes32[] calldata params) external override {
        require(IOAXDEX_Governance(governance).isVotingContract(msg.sender), "Not from voting");
        require(params.length > 1, "Invalid length");
        bytes32 name = params[0];
        bytes32 param1 = params[1];
        // most frequenly used parameter comes first
        if (name == "setProtocolFee") {
            uint256 length = params.length - 1;
            require(length % 2 == 0, "Invalid length");
            length = length / 2;
            uint256[] memory stakeAmount;
            uint256[] memory protocolFee;
            assembly {
                let size := mul(length, 0x20)
                let mark := mload(0x40)
                mstore(0x40, add(mark, add(size, 0x20))) // malloc
                mstore(mark, length) // array length
                calldatacopy(add(mark, 0x20), 0x64, size) // copy data to list
                stakeAmount := mark

                mark := mload(0x40)
                mstore(0x40, add(mark, add(size, 0x20))) // malloc
                mstore(mark, length) // array length
                calldatacopy(add(mark, 0x20), add(0x64, size), size) // copy data to list
                protocolFee := mark
            }
            IOSWAP_RangeFactory(factory).setLiquidityProviderShare(stakeAmount, protocolFee);
        } else if (params.length == 2) {
            if (name == "setTradeFee") {
                IOSWAP_RangeFactory(factory).setTradeFee(uint256(param1));
            } else if (name == "setProtocolFeeTo") {
                IOSWAP_RangeFactory(factory).setProtocolFeeTo(address(bytes20(param1)));
            } else if (name == "setLive") {
                IOSWAP_RangeFactory(factory).setLive(uint256(param1)!=0);
            } else {
                revert("Unknown command");
            }
        } else if (params.length == 3) {
            if (name == "setLiveForPair") {
                IOSWAP_RangeFactory(factory).setLiveForPair(address(bytes20(param1)), uint256(params[2])!=0);
            } else {
                revert("Unknown command");
            }
        } else if (params.length == 6) {
            if (name == "registerProtocol") {
                IOSWAP_HybridRouterRegistry(hybridRegistry).registerProtocol(bytes20(param1), address(bytes20(params[2])), uint256(params[3]), uint256(params[4]), uint256(params[5]));
            } else {
                revert("Unknown command");
            }
        } else {
            revert("Invalid parameters");
        }
    }
}
