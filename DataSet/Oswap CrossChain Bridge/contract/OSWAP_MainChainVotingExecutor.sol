// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import './OSWAP_ChainRegistry.sol';
import './OSWAP_MainChainTrollRegistry.sol';
import './OSWAP_VotingManager.sol';

contract OSWAP_MainChainVotingExecutor {

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    event Execute(bytes32[] params);

    address owner;

    OSWAP_MainChainTrollRegistry public immutable trollRegistry;
    OSWAP_VotingManager public immutable votingManager;
    OSWAP_ChainRegistry public chainRegistry;

    constructor(OSWAP_VotingManager _votingManager) {
        OSWAP_MainChainTrollRegistry _trollRegistry = _votingManager.trollRegistry();
        trollRegistry = _trollRegistry;
        votingManager = _votingManager;
        owner = msg.sender;
    }

    function initAddress(OSWAP_ChainRegistry _chainRegistry) external onlyOwner {
        chainRegistry = _chainRegistry;
        owner = address(0);
    }

    function getChainId() internal view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    function execute(bytes32[] calldata params) external {
        require(votingManager.isVotingContract(msg.sender), "OSWAP_VotingExecutor: Not from voting");
        require(params.length > 0, "Invalid params length");

        emit Execute(params);

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
            if (name == "sideChainConfig") {
                sideChainConfig(params[1:]);
                return;
            } else {
                if (params.length == 2) {
                    if (name == "setAdmin") {
                        votingManager.setAdmin(address(bytes20(param1)));
                        return;
                    } else if (name == "upgradeVotingManager") {
                        votingManager.upgrade(OSWAP_VotingManager(address(bytes20(param1))));
                        return;
                    }
                } else {
                    bytes32 param2 = params[2];
                    if (params.length == 3) {
                        if (name == "setVotingExecutor") {
                            votingManager.setVotingExecutor(address(bytes20(param1)), uint256(param2)!=0);
                            return;
                        } else if (name == "upgradeTrollRegistry") {
                            // only update if chain id match main chain
                            if (uint256(param1) == getChainId())
                                trollRegistry.upgrade(address(bytes20(param2)));
                            return;
                        }
                    } else {
                        bytes32 param3 = params[3];
                        if (params.length == 4) {
                            if (name == "setVotingConfig") {
                                votingManager.setVotingConfig(param1, param2, uint256(param3));
                                return;
                            }
                        } else {
                            if (params.length == 7) {
                                if (name == "addVotingConfig") {
                                    votingManager.addVotingConfig(param1, uint256(param2), uint256(param3), uint256(params[4]), uint256(params[5]), uint256(params[6]));
                                    return;
                                }
                            }
                        }
                    }
                }
            }
        }
        revert("Invalid parameters");
    }

    // ["sideChainConfig", {"setConfig","setConfigAddress","setConfig2"}, (num_chain), [chainId...], [params...]];
    function sideChainConfig(bytes32[] calldata params) internal {
        require(params.length > 2, "Invalid parameters");
        bytes32 name =  params[0];
        uint256 length = uint256(params[1]) + 2;
        if (params.length > length + 1) {
            bytes32 param1 = params[length];
            bytes32 param2 = params[length+1];

            if (params.length == length + 2) {
                if (name == "setConfig") {
                    for (uint256 i = 2 ; i < length ; i++)
                        chainRegistry.configStore(uint256(params[i])).setConfig(param1, param2);
                    return;
                } else if (name == "setConfigAddress") {
                    for (uint256 i = 2 ; i < length ; i++)
                        chainRegistry.configStore(uint256(params[i])).setConfigAddress(param1, param2);
                    return;
                }
            } else {
                bytes32 param3 = params[length + 2];
                if (params.length == length + 3) {
                    if (name == "setConfig2") {
                        for (uint256 i = 2 ; i < length ; i++)
                            chainRegistry.configStore(uint256(params[i])).setConfig2(param1, param2, param3);
                        return;
                    }
                }
            }
        }
        revert("Invalid parameters");
    }
}