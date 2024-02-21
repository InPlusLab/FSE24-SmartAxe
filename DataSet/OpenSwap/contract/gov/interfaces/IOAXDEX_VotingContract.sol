// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

interface IOAXDEX_VotingContract {

    function governance() external view returns (address);
    function executor() external view returns (address);

    function id() external view returns (uint256);
    function name() external view returns (bytes32);
    function _options(uint256) external view returns (bytes32);
    function quorum() external view returns (uint256);
    function threshold() external view returns (uint256);

    function voteStartTime() external view returns (uint256);
    function voteEndTime() external view returns (uint256);
    function executeDelay() external view returns (uint256);

    function executed() external view returns (bool);
    function vetoed() external view returns (bool);

    function accountVoteOption(address) external view returns (uint256);
    function accountVoteWeight(address) external view returns (uint256);

    function _optionsWeight(uint256) external view returns (uint256);
    function totalVoteWeight() external view returns (uint256);
    function totalWeight() external view returns (uint256);
    function _executeParam(uint256) external view returns (bytes32);

    function getParams() external view returns (
        address executor_,
        uint256 id_,
        bytes32 name_,
        bytes32[] memory options_,
        uint256 voteStartTime_,
        uint256 voteEndTime_,
        uint256 executeDelay_,
        bool[2] memory status_, // [executed, vetoed]
        uint256[] memory optionsWeight_,
        uint256[3] memory quorum_, // [quorum, threshold, totalWeight]
        bytes32[] memory executeParam_
    );

    function veto() external;
    function optionsCount() external view returns(uint256);
    function options() external view returns (bytes32[] memory);
    function optionsWeight() external view returns (uint256[] memory);
    function execute() external;
    function vote(uint256 option) external;
    function updateWeight(address account) external;
    function executeParam() external view returns (bytes32[] memory);
}