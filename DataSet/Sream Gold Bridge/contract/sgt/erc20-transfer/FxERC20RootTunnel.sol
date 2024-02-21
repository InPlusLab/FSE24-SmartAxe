// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "../../lib/ERC20.sol";
import {FxBaseRootTunnel} from "../../tunnel/FxBaseRootTunnel.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title FxERC20RootTunnel
 */
contract FxStreamRootTunnel is FxBaseRootTunnel {
    using SafeERC20 for IERC20;
    // maybe DEPOSIT and MAP_TOKEN can be reduced to bytes4
    bytes32 public constant DEPOSIT = keccak256("DEPOSIT");
    bytes32 public constant MAP_TOKEN = keccak256("MAP_TOKEN");

    event TokenMappedERC20(address indexed rootToken, address indexed bridgeToken);
    event FxWithdrawERC20(
        address indexed rootToken,
        address indexed bridgeToken,
        address indexed userAddress,
        uint256 amount
    );
    event FxDepositERC20(
        address indexed rootToken,
        address indexed depositor,
        address indexed userAddress,
        uint256 amount
    );

    mapping(address => address) public rootToBridgeTokens;

    constructor(
        address _checkpointManager,
        address _fxRoot
    ) FxBaseRootTunnel(_checkpointManager, _fxRoot) {
    }

    /**
     * @notice Map a token to enable its movement via the PoS Portal, callable only by mappers
     * @param rootToken address of Stream token on root chain
     */
    function mapToken(address rootToken, address _bridgeToken) public {
        // check if token is already mapped
        require(rootToBridgeTokens[rootToken] == address(0x0), "FxERC20RootTunnel: ALREADY_MAPPED");

        // MAP_TOKEN, encode(rootToken, name, symbol, decimals)
        bytes memory message = abi.encode(MAP_TOKEN, abi.encode(rootToken, _bridgeToken));
        _sendMessageToBridge(message);

        // add into mapped Stream tokens
        rootToBridgeTokens[rootToken] = _bridgeToken;
        emit TokenMappedERC20(rootToken, _bridgeToken);
    }

    function deposit(
        address rootToken,
        address bridgeToken,
        address user,
        uint256 amount,
        bytes memory data
    ) public {
        // map token if not mapped
        if (rootToBridgeTokens[rootToken] == address(0x0)) {
            mapToken(rootToken, bridgeToken);
        }

        // transfer from depositor to this smart contract
        IERC20(rootToken).safeTransferFrom(
            msg.sender, // depositor
            address(this), // manager contract
            amount
        );

        // DEPOSIT, encode(rootToken, depositor, user, amount, extra data)
        bytes memory message = abi.encode(DEPOSIT, abi.encode(rootToken, msg.sender, user, amount, data));
        _sendMessageToBridge(message);
        emit FxDepositERC20(rootToken, msg.sender, user, amount);
    }

    // exit processor
    function _processMessageFromBridge(bytes memory data) internal override {
        (address rootToken, address bridgeToken, address to, uint256 amount) = abi.decode(
            data,
            (address, address, address, uint256)
        );
        // validate mapping for root to bridge
        require(rootToBridgeTokens[rootToken] == bridgeToken, "FxERC20RootTunnel: INVALID_MAPPING_ON_EXIT");

        // transfer from Stream tokens to
        IERC20(rootToken).safeTransfer(to, amount);
        emit FxWithdrawERC20(rootToken, bridgeToken, to, amount);
    }
}
