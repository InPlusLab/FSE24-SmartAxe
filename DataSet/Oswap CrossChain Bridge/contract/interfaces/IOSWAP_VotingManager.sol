// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "./IAuthorization.sol";
import "./IOSWAP_MainChainTrollRegistry.sol";
import "./IOSWAP_VotingExecutorManager.sol";

interface IOSWAP_VotingManager is IAuthorization, IOSWAP_VotingExecutorManager {

    struct VotingConfig {
        uint256 minExeDelay;
        uint256 minVoteDuration;
        uint256 maxVoteDuration;
        uint256 minGovTokenToCreateVote;
        uint256 minQuorum;
    }

    event ParamSet(bytes32 indexed name, bytes32 value);
    event ParamSet2(bytes32 name, bytes32 value1, bytes32 value2);
    event AddVotingConfig(
        bytes32 name,
        uint256 minExeDelay,
        uint256 minVoteDuration,
        uint256 maxVoteDuration,
        uint256 minGovTokenToCreateVote,
        uint256 minQuorum);
    event SetVotingConfig(bytes32 indexed configName, bytes32 indexed paramName, uint256 minExeDelay);
    event NewVote(address indexed vote);
    event NewPoll(address indexed poll);
    event Vote(address indexed account, address indexed vote, uint256 option);
    event Poll(address indexed account, address indexed poll, uint256 option);
    event Executed(address indexed vote);
    event Veto(address indexed vote);
    event Upgrade(IOSWAP_VotingManager newVotingManager);

    // function govToken() external view returns (IERC20 govToken);
    // function trollRegistry() external view returns (IOSWAP_MainChainTrollRegistry trollRegistry);
    function votingRegister() external view returns (address votingRegister);

    function votingConfigs(bytes32) external view returns (VotingConfig memory votingConfigs);
    function votingConfigProfiles(uint256 index) external view returns (bytes32);
    // function votingExecutor(uint256 index) external view returns (address);
    // function votingExecutorInv(address) external view returns (uint256 votingExecutorInv);
    // function isVotingExecutor(address) external view returns (bool isVotingExecutor);
    function admin() external view returns (address admin);
    function voteCount() external view returns (uint256 voteCount);
    function votingIdx(address) external view returns (uint256 votingIdx);
    function votings(uint256 index) external view returns (address);
    // function trollRegistry() external view returns (address trollRegistry);
    function newVotingManager() external view returns (IOSWAP_VotingManager newVotingManager);
    // function newVotingExecutorManager() external view returns (IOSWAP_VotingExecutorManager newVotingExecutorManager);

    function setVotingRegister(address _votingRegister) external;
    function initVotingExecutor(address[] calldata  _votingExecutor) external;

    function upgrade(IOSWAP_VotingManager _votingManager) external;
    function upgradeByAdmin(IOSWAP_VotingManager _votingManager) external;
	function votingConfigProfilesLength() external view returns(uint256);
	function getVotingConfigProfiles(uint256 start, uint256 length) external view returns(bytes32[] memory profiles);
    function getVotingParams(bytes32 name) external view returns (uint256 _minExeDelay, uint256 _minVoteDuration, uint256 _maxVoteDuration, uint256 _minGovTokenToCreateVote, uint256 _minQuorum);

    // function votingExecutorLength() external view returns (uint256);
    // function setVotingExecutor(address _votingExecutor, bool _bool) external;
    function initAdmin(address _admin) external;
    function setAdmin(address _admin) external;
    function addVotingConfig(bytes32 name, uint256 minExeDelay, uint256 minVoteDuration, uint256 maxVoteDuration, uint256 minGovTokenToCreateVote, uint256 minQuorum) external;
    function setVotingConfig(bytes32 configName, bytes32 paramName, uint256 paramValue) external;

    function allVotings() external view returns (address[] memory);
    function getVotingCount() external view returns (uint256);
    function getVotings(uint256 start, uint256 count) external view returns (address[] memory _votings);
    function isVotingContract(address votingContract) external view returns (bool);

    function getNewVoteId() external returns (uint256);
    function newVote(address vote, bool isExecutiveVote) external;
    function voted(bool poll, address account, uint256 option) external;
    function executed() external;
    function veto(address voting) external;
    function closeVote(address vote) external;
}