// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../gov/interfaces/IOAXDEX_VotingExecutor.sol';
import './interfaces/IOSWAP_Factory.sol';
import '../gov/interfaces/IOAXDEX_Governance.sol';

contract OSWAP_VotingExecutor1 is IOAXDEX_VotingExecutor {

    address public governance;
    address public factory;
    
    constructor(address _factory) public {
        factory = _factory;
        governance = IOSWAP_Factory(_factory).governance();
    }

    function execute(bytes32[] calldata params) external override {
        require(IOAXDEX_Governance(governance).isVotingContract(msg.sender), "Not from voting");
        bytes32 name = params[0];
        bytes32 param1 = params[1];
        // most frequenly used parameter comes first
        if (params.length == 2) {
            if (name == "setTradeFee") {
                IOSWAP_Factory(factory).setTradeFee(uint256(param1));
            } else if (name == "setProtocolFee") {
                IOSWAP_Factory(factory).setProtocolFee(uint256(param1));
            } else if (name == "setProtocolFeeTo") {
                IOSWAP_Factory(factory).setProtocolFeeTo(address(bytes20(param1)));
            } else if (name == "setLive") {
                IOSWAP_Factory(factory).setLive(uint256(param1)!=0);
            } else {
                revert("Unknown command");
            }
        } else if (params.length == 3) {
            if (name == "setLiveForPair") {
                IOSWAP_Factory(factory).setLiveForPair(address(bytes20(param1)), uint256(params[2])!=0);
            } else {
                revert("Unknown command");
            }
        } else {
            revert("Invalid parameters");
        }
    }
}
