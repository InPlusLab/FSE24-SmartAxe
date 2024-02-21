// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

contract OSWAP_ConfigStoreTradeVault {

    // modifier onlyVoting() {
    //     require(votingManager.isVotingExecutor(msg.sender), "OSWAP: Not from voting");
    //     _;
    // }

    event ParamSet1(bytes32 indexed name, bytes32 value1);

    // IERC20 public immutable govToken;
    // OSWAP_VotingManager public votingManager;

    address public router;
    uint256 public arbitrageFee;
    address public feeTo;

    OSWAP_ConfigStoreTradeVault public newConfigStore;

    constructor(
        // OSWAP_VotingManager _votingManager,
        uint256 _arbitrageFee,
        address _router
    ) {
        // govToken = _votingManager.govToken();
        // votingManager = _votingManager;
        arbitrageFee = _arbitrageFee;
        router = _router;
        newConfigStore = this;
    }

    function setConfigAddress(bytes32 name, bytes32 _value) external /*onlyVoting*/ {
        address value = address(bytes20(_value));

        if (name == "router") {
            router = value;
        } else if (name == "newConfigStore") {
            newConfigStore = OSWAP_ConfigStoreTradeVault(value);
        } else {
            revert("Invalid config");
        }
        emit ParamSet1(name, _value);
    }
    function setConfig(bytes32 name, bytes32 _value) external /*onlyVoting*/ {
        uint256 value = uint256(_value);
        if (name == "arbitrageFee") {
            arbitrageFee = value;
        } else {
            revert("Invalid config");
        }
        emit ParamSet1(name, _value);
    }
    function getTradeParam(/*IERC20 asset*/) external view returns (address,uint256) {
        return (router, arbitrageFee);
    }
}
