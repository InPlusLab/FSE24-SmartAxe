// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStateSender {
    function syncState(address receiver, bytes calldata data) external;
}

interface IFxStateSender {
    function sendMessageToBridge(address _receiver, bytes calldata _data) external;
}

/**
 * @title FxRoot root contract for fx-portal
 */
contract FxRoot is IFxStateSender {
    IStateSender public stateSender;
    address public fxBridge;

    constructor(address _stateSender) {
        stateSender = IStateSender(_stateSender);
    }

    function setFxBridge(address _fxBridge) public {
        require(fxBridge == address(0x0));
        fxBridge = _fxBridge;
    }

    function sendMessageToBridge(address _receiver, bytes calldata _data) public override {
        bytes memory data = abi.encode(msg.sender, _receiver, _data);
        stateSender.syncState(fxBridge, data);
    }
}
