// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './interfaces/IOSWAP_PausablePair.sol';

contract OSWAP_PausablePair is IOSWAP_PausablePair {
    bool public override isLive;
    address public override immutable factory;

    constructor() public {
        factory = msg.sender;
        isLive = true;
    }
    function setLive(bool _isLive) external override {
        require(msg.sender == factory, 'FORBIDDEN');
        isLive = _isLive;
    }
}