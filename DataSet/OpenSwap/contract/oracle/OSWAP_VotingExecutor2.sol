// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../gov/interfaces/IOAXDEX_VotingExecutor.sol';
import './interfaces/IOSWAP_OracleFactory.sol';
import '../gov/interfaces/IOAXDEX_Governance.sol';

contract OSWAP_VotingExecutor2 is IOAXDEX_VotingExecutor {

    address public immutable governance;
    address public immutable factory;
    
    constructor(address _factory) public {
        factory = _factory;
        governance = IOSWAP_OracleFactory(_factory).governance();
    }

    function execute(bytes32[] calldata params) external override {
        require(IOAXDEX_Governance(governance).isVotingContract(msg.sender), "Not from voting");
        bytes32 name = params[0];
        bytes32 param1 = params[1];
        // most frequenly used parameter comes first
        if (params.length == 4) {
            if (name == "setOracle") {
                IOSWAP_OracleFactory(factory).setOracle(address(bytes20(param1)), address(bytes20(params[2])), address(bytes20(params[3])));
            } else if (name == "addOldOracleToNewPair") {
                IOSWAP_OracleFactory(factory).addOldOracleToNewPair(address(bytes20(param1)), address(bytes20(params[2])), address(bytes20(params[3])));
            } else {
                revert("Unknown command");
            }
        } else if (params.length == 2) {
            if (name == "setTradeFee") {
                IOSWAP_OracleFactory(factory).setTradeFee(uint256(param1));
            } else if (name == "setProtocolFee") {
                IOSWAP_OracleFactory(factory).setProtocolFee(uint256(param1));
            } else if (name == "setFeePerDelegator") {
                IOSWAP_OracleFactory(factory).setFeePerDelegator(uint256(param1));
            } else if (name == "setProtocolFeeTo") {
                IOSWAP_OracleFactory(factory).setProtocolFeeTo(address(bytes20(param1)));
            } else if (name == "setLive") {
                IOSWAP_OracleFactory(factory).setLive(uint256(param1)!=0);
            } else {
                revert("Unknown command");
            }
        } else if (params.length == 3) {
            if (name == "setMinLotSize") {
                IOSWAP_OracleFactory(factory).setMinLotSize(address(bytes20(param1)), uint256(params[2]));
            } else if (name == "setSecurityScoreOracle") {
                IOSWAP_OracleFactory(factory).setSecurityScoreOracle(address(bytes20(param1)), uint256(params[2]));
            } else if (name == "setLiveForPair") {
                IOSWAP_OracleFactory(factory).setLiveForPair(address(bytes20(param1)), uint256(params[2])!=0);
            } else if (name == "setWhiteList") {
                IOSWAP_OracleFactory(factory).setWhiteList(address(bytes20(param1)), uint256(params[2])!=0);
            } else {
                revert("Unknown command");
            }
        } else {
            revert("Invalid parameters");
        }
    }
}
