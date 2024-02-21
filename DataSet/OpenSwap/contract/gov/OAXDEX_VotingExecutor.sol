// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './interfaces/IOAXDEX_VotingExecutor.sol';
import './interfaces/IOAXDEX_Governance.sol';
import './interfaces/IOAXDEX_Administrator.sol';

contract OAXDEX_VotingExecutor is IOAXDEX_VotingExecutor {

    address public governance;
    address public admin;
    
    constructor(address _governance, address _admin) public {
        governance = _governance;
        admin = _admin;
    }

    function execute(bytes32[] calldata params) external override {
        require(IOAXDEX_Governance(governance).isVotingContract(msg.sender), "OAXDEX_VotingExecutor: Not from voting");
        bytes32 name = params[0];
        bytes32 param1 = params[1];
        // most frequenly used parameter comes first
        if (params.length == 4) {
            if (name == "setVotingConfig") {
                IOAXDEX_Governance(governance).setVotingConfig(param1, params[2], uint256(params[3]));
            } else {
                revert("OAXDEX_VotingExecutor: Unknown command");
            }
        } else if (params.length == 2) {
            if (name == "setMinStakePeriod") {
                IOAXDEX_Governance(governance).setMinStakePeriod(uint256(param1));
            } else if (name == "setMaxAdmin") {
                IOAXDEX_Administrator(admin).setMaxAdmin(uint256(param1));
            } else if (name == "addAdmin") {
                IOAXDEX_Administrator(admin).addAdmin(address(bytes20(param1)));
            } else if (name == "removeAdmin") {
                IOAXDEX_Administrator(admin).removeAdmin(address(bytes20(param1)));
            } else if (name == "setAdmin") {
                IOAXDEX_Governance(governance).setAdmin(address(bytes20(param1)));
            } else {
                revert("OAXDEX_VotingExecutor: Unknown command");
            }
        } else if (params.length == 3) {
            if (name == "setVotingExecutor") {
                IOAXDEX_Governance(governance).setVotingExecutor(address(bytes20(param1)), uint256(params[2])!=0);
            } else {
                revert("OAXDEX_VotingExecutor: Unknown command");
            }
        } else if (params.length == 7) {
            if (name == "addVotingConfig") {
                IOAXDEX_Governance(governance).addVotingConfig(param1, uint256(params[2]), uint256(params[3]), uint256(params[4]), uint256(params[5]), uint256(params[6]));
            } else {
                revert("OAXDEX_VotingExecutor: Unknown command");
            }
        } else {
            revert("OAXDEX_VotingExecutor: Invalid parameters");
        }
    }
}
