// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import "./interfaces/IOSWAP_ConfigStore.sol";
import '../gov/interfaces/IOAXDEX_Governance.sol';

contract OSWAP_ConfigStore is IOSWAP_ConfigStore {

    modifier onlyVoting() {
        require(IOAXDEX_Governance(governance).isVotingExecutor(msg.sender), "Not from voting");
        _; 
    }

    mapping(bytes32 => bytes32) public override customParam;
    bytes32[] public override customParamNames;
    mapping(bytes32 => uint256) public override customParamNamesIdx;

    address public immutable override governance;
    constructor(address _governance) public {
        governance = _governance;
    }

    function customParamNamesLength() external view override returns (uint256 length) {
        return customParamNames.length;
    }

    function _setCustomParam(bytes32 paramName, bytes32 paramValue) internal {
        customParam[paramName] = paramValue;
        if (customParamNames.length == 0 || customParamNames[customParamNamesIdx[paramName]] != paramName) {
            customParamNamesIdx[paramName] = customParamNames.length;
            customParamNames.push(paramName);
        }
        emit ParamSet(paramName, paramValue);
    }
    function setCustomParam(bytes32 paramName, bytes32 paramValue) external override onlyVoting {
        _setCustomParam(paramName, paramValue);
    }
    function setMultiCustomParam(bytes32[] calldata paramName, bytes32[] calldata paramValue) external override onlyVoting {
        uint256 length = paramName.length;
        require(length == paramValue.length, "length not match");
        for (uint256 i = 0 ; i < length ; i++) {
            _setCustomParam(paramName[i], paramValue[i]);
        }
    }
}