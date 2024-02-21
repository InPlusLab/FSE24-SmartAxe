// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './interfaces/IOSWAP_PausableFactory.sol';
import '../gov/interfaces/IOAXDEX_Governance.sol';
import './interfaces/IOSWAP_PausablePair.sol';

contract OSWAP_PausableFactory is IOSWAP_PausableFactory {

    modifier onlyShutdownAdminOrVoting() {
        require(IOAXDEX_Governance(governance).admin() == msg.sender ||
                IOAXDEX_Governance(governance).isVotingExecutor(msg.sender), 
                "Not from shutdown admin or voting");
        _; 
    }

    address public immutable override governance;

    bool public override isLive;

    constructor(address _governance) public {
        governance = _governance;
        isLive = true;
    }

    function setLive(bool _isLive) external override onlyShutdownAdminOrVoting {
        isLive = _isLive;
        if (isLive)
            emit Restarted();
        else
            emit Shutdowned();
    }
    function setLiveForPair(address pair, bool live) external override onlyShutdownAdminOrVoting {
        IOSWAP_PausablePair(pair).setLive(live);
        if (live)
            emit PairRestarted(pair);
        else
            emit PairShutdowned(pair);
    }
}