// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../gov/interfaces/IOAXDEX_VotingExecutor.sol';
import './interfaces/IOSWAP_RestrictedFactory.sol';
import '../gov/interfaces/IOAXDEX_Governance.sol';
import './interfaces/IOSWAP_ConfigStore.sol';

contract OSWAP_VotingExecutor4 is IOAXDEX_VotingExecutor {

    address public immutable governance;
    address public immutable factory;
    address public immutable configStore;

    constructor(address _governance, address _factory, address _configStore) public {
        factory = _factory;
        governance = _governance;//IOSWAP_RangeFactory(_factory).governance();
        configStore = _configStore;
    }

    function execute(bytes32[] calldata params) external override {
        require(IOAXDEX_Governance(governance).isVotingContract(msg.sender), "Not from voting");
        require(params.length > 1, "Invalid length");
        bytes32 name = params[0];
        bytes32 param1 = params[1];
        // most frequenly used parameter comes first
        if (name == "multiCustomParam") {
            uint256 length = params.length - 1;
            require(length % 2 == 0, "Invalid length");
            length = length / 2;
            bytes32[] memory names;
            bytes32[] memory values;
            assembly {
                let size := mul(length, 0x20)
                let mark := mload(0x40)
                mstore(0x40, add(mark, add(size, 0x20))) // malloc
                mstore(mark, length) // array length
                calldatacopy(add(mark, 0x20), 0x64, size) // copy data to list
                names := mark

                mark := mload(0x40)
                mstore(0x40, add(mark, add(size, 0x20))) // malloc
                mstore(mark, length) // array length
                calldatacopy(add(mark, 0x20), add(0x64, size), size) // copy data to list
                values := mark
            }
            IOSWAP_ConfigStore(configStore).setMultiCustomParam(names, values);
        } else if (params.length == 4) {
            if (name == "setOracle") {
                IOSWAP_RestrictedFactory(factory).setOracle(address(bytes20(param1)), address(bytes20(params[2])), address(bytes20(params[3])));
            } else if (name == "addOldOracleToNewPair") {
                IOSWAP_RestrictedFactory(factory).addOldOracleToNewPair(address(bytes20(param1)), address(bytes20(params[2])), address(bytes20(params[3])));
            } else {
                revert("Unknown command");
            }
        } else if (params.length == 2) {
            if (name == "setTradeFee") {
                IOSWAP_RestrictedFactory(factory).setTradeFee(uint256(param1));
            } else if (name == "setProtocolFee") {
                IOSWAP_RestrictedFactory(factory).setProtocolFee(uint256(param1));
            } else if (name == "setProtocolFeeTo") {
                IOSWAP_RestrictedFactory(factory).setProtocolFeeTo(address(bytes20(param1)));
            } else if (name == "setLive") {
                IOSWAP_RestrictedFactory(factory).setLive(uint256(param1)!=0);
            } else {
                revert("Unknown command");
            }
        } else if (params.length == 3) {
            if (name == "setLiveForPair") {
                IOSWAP_RestrictedFactory(factory).setLiveForPair(address(bytes20(param1)), uint256(params[2])!=0);
            } else if (name == "customParam") {
                IOSWAP_ConfigStore(configStore).setCustomParam(param1, params[2]);
            } else {
                revert("Unknown command");
            }
        } else {
            revert("Invalid parameters");
        }
    }

}
