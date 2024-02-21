// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "./OSWAP_ChainRegistry.sol";
import "./OSWAP_VotingManager.sol";

contract OSWAP_ChainRegistryExecutor {
    OSWAP_VotingManager public immutable votingManager;
    OSWAP_ChainRegistry public immutable chainRegistry;

    event Execute(bytes32[] params);

    constructor(OSWAP_VotingManager _votingManager, OSWAP_ChainRegistry _chainRegistry) {
        votingManager = _votingManager;
        chainRegistry = _chainRegistry;
    }

    function execute(bytes32[] calldata params) external {
        require(votingManager.isVotingContract(msg.sender), "OSWAP_VotingExecutor: Not from voting");
        require(params.length > 0, "Invalid params length");

        emit Execute(params);

        bytes32 name = params[0];

        if (name == "sideChainConfig") {
            sideChainConfig(params[1:]);
            return;
        } else if (name == "newVault") {
            require(params.length >= 6 && (params.length - 2) % 4 == 0, "invalid params length");
            uint256 length = (params.length - 2) / 4;
            uint256[] memory chainId = new uint256[](length);
            assembly {
                // 0x4 (selector) + 0x20 (offset) + 0x20 (length) + 0x40 ("newVault" + name)
                calldatacopy(add(chainId,0x20), 0x84, mul(0x20, length))
            }
            OSWAP_ChainRegistry.Vault[] memory vault = new OSWAP_ChainRegistry.Vault[](length);
            uint256 j = length + 2;
            for (uint256 i ; i < length ; i++) {
                vault[i] = OSWAP_ChainRegistry.Vault({
                    token: address(bytes20(params[j++])),
                    vaultRegistry: address(bytes20(params[j++])),
                    bridgeVault: address(bytes20(params[j++]))
                });
            }
            // newVault(bytes32 name, uint256[] memory chainId, Vault[] memory vault)
            chainRegistry.newVault(params[1], chainId, vault);
            return;
        } else if (name == "addChain") {
            require(params.length >= 5 && (params.length - 5) % 2 == 0, "invalid params length");
            uint256 length = (params.length - 5) / 2;
            uint256 cut = length + 5;
            address[] memory addr = new address[](length);
            for (uint256 i ; i < length ; i++) {
                addr[i] = address(bytes20(params[cut + i]));
            }
            // addChain(uint256 chainId, Status _status, IERC20 _govToken, OSWAP_ConfigStore _configStore,  bytes32[] memory contractNames, address[] memory _address)
            chainRegistry.addChain(
                uint256(params[1]), 
                OSWAP_ChainRegistry.Status(uint256(params[2])), 
                IERC20(address(bytes20(params[3]))),
                OSWAP_ConfigStore(address(bytes20(params[4]))),
                params[5:cut],
                addr);
            return;
        } else if (name == "updateStatus") {
            require(params.length == 3, "invalid params length");
            // updateStatus(uint256 chainId, Status _status)
            chainRegistry.updateStatus(uint256(params[1]), OSWAP_ChainRegistry.Status(uint256(params[2])));
            return;
        } else if (name == "updateVault") {
            require(params.length == 6, "invalid params length");
            // updateVault(uint256 index, uint256 chainId, Vault memory vault)
            chainRegistry.updateVault(
                uint256(params[1]), 
                uint256(params[2]), 
                OSWAP_ChainRegistry.Vault({
                    token: address(bytes20(params[3])),
                    vaultRegistry: address(bytes20(params[4])),
                    bridgeVault: address(bytes20(params[5]))
                })
            );
            return;
        } else if (name == "updateAddress") {
            require(params.length == 4, "invalid params length");
            // updateAddress(uint256 chainId, bytes32 contractName, address _address)
            chainRegistry.updateAddress(uint256(params[1]), bytes32(params[2]), address(bytes20(params[3])));
            return;
        } else if (name == "updateAddresses") {
            require(params.length >= 4 && (params.length - 2) % 2 == 0, "invalid params length");
            uint256 length = (params.length - 2) / 2;
            uint256 cut = length + 2;
            address[] memory addr = new address[](length);
            for (uint256 i ; i < length ; i++) {
                addr[i] = address(bytes20(params[cut + i]));
            }
            // updateAddresses(uint256 chainId, bytes32[] memory contractNames, address[] memory _addresses)
            chainRegistry.updateAddresses(uint256(params[1]),params[2:cut],addr);
            return;
        } else if (name == "updateMainChainAddress") {
            require(params.length == 3, "invalid params length");
            // updateMainChainAddress(bytes32 contractName, address _address)
            chainRegistry.updateMainChainAddress(bytes32(params[1]), address(bytes20(params[2])));
            return;
        } else if (name == "updateConfigStore") {
            require(params.length == 3, "invalid params length");
            // updateConfigStore(uint256 chainId, OSWAP_ConfigStore _address)
            chainRegistry.updateConfigStore(uint256(params[1]), OSWAP_ConfigStore(address(bytes20(params[2]))));
            return;
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