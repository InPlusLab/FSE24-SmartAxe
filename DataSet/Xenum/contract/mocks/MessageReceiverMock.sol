// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IMessageReceiver.sol";

contract MessageReceiverMock is IMessageReceiver {
	mapping (bytes => bool) public hardFailOn;
	mapping (bytes => bool) public softFailOn;

	uint256 public stuff;

	function receiveBridgeMessage(
		string calldata,
		uint256,
		bytes calldata message
	) external override returns (bool) {
		require(!hardFailOn[message], "MessageReceiverMock: Hard fail");
		if (softFailOn[message]) return false;

		stuff = stuff + 1;

		return true;
	}

	function setHardFail(bytes memory message, bool fail) external {
		hardFailOn[message] = fail;
	}

	function setSoftFail(bytes memory message, bool fail) external {
		softFailOn[message] = fail;
	}
}
