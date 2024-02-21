// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxBaseBridgeTunnel} from "../../tunnel/FxBaseBridgeTunnel.sol";
import {IFxERC20} from "../../tokens/IFxERC20.sol";

/**
 * @title FxERC20BridgeTunnel
 */
contract FxERC20BridgeTunnel is FxBaseBridgeTunnel {
    bytes32 public constant DEPOSIT = keccak256("DEPOSIT");
    bytes32 public constant MAP_TOKEN = keccak256("MAP_TOKEN");
    string public constant SUFFIX_NAME = " (FXERC20)";
    string public constant PREFIX_SYMBOL = "fx";

    // event for Stream Gold token maping
    event TokenMapped(address indexed rootToken, address indexed bridgeToken);
    // root to Bridge token
    mapping(address => address) public rootToBridgeToken;

    constructor(address _fxBridge) FxBaseBridgeTunnel(_fxBridge) {
    }

    function withdraw(address bridgeToken, uint256 amount) public {
        _withdraw(bridgeToken, msg.sender, amount);
    }

    function withdrawTo(
        address bridgeToken,
        address receiver,
        uint256 amount
    ) public {
        _withdraw(bridgeToken, receiver, amount);
    }

    //
    // Internal methods
    //

    function _processMessageFromRoot(
        uint256, /* stateId */
        address sender,
        bytes memory data
    ) internal override validateSender(sender) {
        // decode incoming data
        (bytes32 syncType, bytes memory syncData) = abi.decode(data, (bytes32, bytes));

        if (syncType == DEPOSIT) {
            _syncDeposit(syncData);
        } else if (syncType == MAP_TOKEN) {
            _mapToken(syncData);
        } else {
            revert("FxERC20BridgeTunnel: INVALID_SYNC_TYPE");
        }
    }

    function _mapToken(bytes memory syncData) internal {
        (address rootToken,address _bridgeToken) = abi.decode(
            syncData,
            (address,address)
        );
        require(_bridgeToken != address(0x0), "Not the zeroth address");

        address bridgeToken = rootToBridgeToken[rootToken];
        // check if it's already mapped
        require(bridgeToken == address(0x0), "FxERC20BridgeTunnel: ALREADY_MAPPED");

        // map the token
        rootToBridgeToken[rootToken] = _bridgeToken;
        emit TokenMapped(rootToken, _bridgeToken);
    }

    function _syncDeposit(bytes memory syncData) internal {
        (address rootToken, address depositor, address to, uint256 amount, bytes memory depositData) = abi.decode(
            syncData,
            (address, address, address, uint256, bytes)
        );
        address bridgeToken = rootToBridgeToken[rootToken];
        require(bridgeToken != address(0), "Bridge Token cannot be zero address");
        // deposit tokens
        IFxERC20 bridgeTokenContract = IFxERC20(bridgeToken);
        bridgeTokenContract.mint(to, amount);

        // call `onTokenTranfer` on `to` with limit and ignore error
        // onTokenTransfer ERC223
        if (_isContract(to)) {
            uint256 txGas = 2000000;
            bool success = false;
            bytes memory data = abi.encodeWithSignature(
                "onTokenTransfer(address,address,address,address,uint256,bytes)",
                rootToken,
                bridgeToken,
                depositor,
                to,
                amount,
                depositData
            );
            // solium-disable-next-line security/no-inline-assembly
            assembly {
                success := call(txGas, to, 0, add(data, 0x20), mload(data), 0, 0)
            }
        }
    }

    function _withdraw(
        address bridgeToken,
        address receiver,
        uint256 amount
    ) internal {
        IFxERC20 bridgeTokenContract = IFxERC20(bridgeToken);
        // child token contract will have root token
        address rootToken = bridgeTokenContract.connectedToken();

        // validate root and Bridge token mapping
        require(
            bridgeToken != address(0x0) && rootToken != address(0x0) && bridgeToken == rootToBridgeToken[rootToken],
            "FxERC20BridgeTunnel: NO_MAPPED_TOKEN"
        );

        // withdraw Stream tokens
        bridgeTokenContract.burn(msg.sender, amount);

        // send message to root regarding token burn
        _sendMessageToRoot(abi.encode(rootToken, bridgeToken, receiver, amount));
    }

    // check if address is smart contract
    function _isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
