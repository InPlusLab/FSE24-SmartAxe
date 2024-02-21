// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import './OSWAP_ConfigStore.sol';
import "./OSWAP_SideChainTrollRegistry.sol";

contract OSWAP_SideChainVotingExecutor {
    event Execute(bytes32[] params);

    // from VotingManager
    IERC20 public immutable govToken;
    OSWAP_SideChainTrollRegistry public immutable trollRegistry;
    OSWAP_ConfigStore public configStore;

    constructor(OSWAP_SideChainTrollRegistry _trollRegistry) {
        trollRegistry = _trollRegistry;
        configStore = _trollRegistry.configStore();
        govToken = _trollRegistry.govToken();
    }

    function executeHash(bytes32[] calldata params, uint256 nonce) public view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return keccak256(abi.encodePacked(
            chainId,
            address(this),
            params,
            nonce
        ));
    }
    function execute(bytes[] calldata signatures, bytes32[] calldata params, uint256 nonce) external {
        require(params.length > 0, "Invalid params length");

        emit Execute(params);

        bytes32 hash = executeHash(params, nonce);
        trollRegistry.verifySignatures(msg.sender, signatures, hash, nonce);

        bytes32 name = params[0];
        if (params.length == 1) {
            if (name == "shutdown") {
                trollRegistry.shutdownByVoting();
                return;
            } else if (name == "resume") {
                trollRegistry.resume();
                return;
            }
        } else {
            bytes32 param1 = params[1];
            if (params.length == 2) {
                if (name == "upgradeConfigStore") {
                    configStore.upgrade(OSWAP_ConfigStore(address(bytes20(param1))));
                    return;
                } else if (name == "upgradeTrollRegistry") {
                    trollRegistry.upgrade(address(bytes20(param1)));
                    return;
                }
            } else {
                bytes32 param2 = params[2];
                if (params.length == 3) {
                    if (name == "setConfig") {
                        configStore.setConfig(param1, param2);
                        return;
                    } else if (name == "setConfigAddress") {
                        configStore.setConfigAddress(param1, param2);
                        return;
                    } else if (name == "setVotingExecutor") {
                        trollRegistry.setVotingExecutor(address(bytes20(param1)), uint256(param2)!=0);
                        return;
                    }
                } else {
                    bytes32 param3 = params[3];
                    if (params.length == 4) {
                        if (name == "setConfig2") {
                            configStore.setConfig2(param1, param2, param3);
                            return;
                        }
                    }
                }
            }
        }
        revert("Invalid parameters");
    }
}
