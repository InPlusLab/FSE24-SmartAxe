// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "./Authorization.sol";
import "./OSWAP_MainChainTrollRegistry.sol";
import "./OSWAP_VotingContract.sol";

contract OSWAP_VotingManager is Authorization {

    uint256 constant WEI = 10 ** 18;

    modifier onlyVoting() {
        require(isVotingExecutor[msg.sender], "OSWAP: Not from voting");
        _;
    }
    modifier onlyVotingRegistry() {
        require(msg.sender == votingRegister, "Governance: Not from votingRegistry");
        _;
    }

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
    event Upgrade(OSWAP_VotingManager newVotingManager);

    IERC20 public immutable govToken;
    OSWAP_MainChainTrollRegistry public trollRegistry;
    address public votingRegister;

    mapping (bytes32 => VotingConfig) public votingConfigs;
	bytes32[] public votingConfigProfiles;

    address[] public votingExecutor;
    mapping (address => uint256) public votingExecutorInv;
    mapping (address => bool) public isVotingExecutor;
    address public admin;

    uint256 public voteCount;
    mapping (address => uint256) public votingIdx;
    address[] public votings;

    OSWAP_VotingManager public newVotingManager;
    function newVotingExecutorManager() external view returns (address) { return address(newVotingManager); }

    constructor(
        OSWAP_MainChainTrollRegistry _trollRegistry,
        bytes32[] memory _names, 
        uint256[] memory _minExeDelay, 
        uint256[] memory _minVoteDuration, 
        uint256[] memory _maxVoteDuration, 
        uint256[] memory _minGovTokenToCreateVote, 
        uint256[] memory _minQuorum
    ) {
        trollRegistry = _trollRegistry;
        govToken = _trollRegistry.govToken();

        require(_names.length == _minExeDelay.length && 
                _minExeDelay.length == _minVoteDuration.length && 
                _minVoteDuration.length == _maxVoteDuration.length && 
                _maxVoteDuration.length == _minGovTokenToCreateVote.length && 
                _minGovTokenToCreateVote.length == _minQuorum.length, "OSWAP: Argument lengths not matched");
        for (uint256 i = 0 ; i < _names.length ; i++) {
            require(_minExeDelay[i] > 0 && _minExeDelay[i] <= 604800, "OSWAP: Invalid minExeDelay");
            require(_minVoteDuration[i] < _maxVoteDuration[i] && _minVoteDuration[i] <= 604800, "OSWAP: Invalid minVoteDuration");

            VotingConfig storage config = votingConfigs[_names[i]];
            config.minExeDelay = _minExeDelay[i];
            config.minVoteDuration = _minVoteDuration[i];
            config.maxVoteDuration = _maxVoteDuration[i];
            config.minGovTokenToCreateVote = _minGovTokenToCreateVote[i];
            config.minQuorum = _minQuorum[i];
			votingConfigProfiles.push(_names[i]);
            emit AddVotingConfig(_names[i], config.minExeDelay, config.minVoteDuration, config.maxVoteDuration, config.minGovTokenToCreateVote, config.minQuorum);
        }
    }
    function setVotingRegister(address _votingRegister) external onlyOwner {
        require(votingRegister == address(0), "OSWAP: Already set");
        votingRegister = _votingRegister;
        emit ParamSet("votingRegister", bytes32(bytes20(votingRegister)));
    }
    function initVotingExecutor(address[] calldata  _votingExecutor) external onlyOwner {
        require(votingExecutor.length == 0, "OSWAP: executor already set");
        uint256 length = _votingExecutor.length;
        for (uint256 i = 0 ; i < length ; i++) {
            _setVotingExecutor(_votingExecutor[i], true);
        }
    }

    function upgrade(OSWAP_VotingManager _votingManager) external onlyVoting {
        _upgrade(_votingManager);
    }
    function upgradeByAdmin(OSWAP_VotingManager _votingManager) external onlyOwner {
        _upgrade(_votingManager);
    }
    function _upgrade(OSWAP_VotingManager _votingManager) internal {
        // require(address(newVotingManager) == address(0), "already set");
        newVotingManager = _votingManager;
        emit Upgrade(_votingManager);
    }


	function votingConfigProfilesLength() external view returns(uint256) {
		return votingConfigProfiles.length;
	}
	function getVotingConfigProfiles(uint256 start, uint256 length) external view returns(bytes32[] memory profiles) {
		if (start < votingConfigProfiles.length) {
            if (start + length > votingConfigProfiles.length)
                length = votingConfigProfiles.length - start;
            profiles = new bytes32[](length);
            for (uint256 i = 0 ; i < length ; i++) {
                profiles[i] = votingConfigProfiles[i + start];
            }
        }
	}
    function getVotingParams(bytes32 name) external view returns (uint256 _minExeDelay, uint256 _minVoteDuration, uint256 _maxVoteDuration, uint256 _minGovTokenToCreateVote, uint256 _minQuorum) {
        VotingConfig storage config = votingConfigs[name];
        if (config.minGovTokenToCreateVote == 0){
            config = votingConfigs["vote"];
        }
        return (config.minExeDelay, config.minVoteDuration, config.maxVoteDuration, config.minGovTokenToCreateVote, config.minQuorum);
    }

    function votingExecutorLength() external view returns (uint256) {
        return votingExecutor.length;
    }
    function setVotingExecutor(address _votingExecutor, bool _bool) external onlyVoting {
        _setVotingExecutor(_votingExecutor, _bool);
    }
    function _setVotingExecutor(address _votingExecutor, bool _bool) internal {
        require(_votingExecutor != address(0), "OSWAP: Invalid executor");

        if (votingExecutor.length==0 || votingExecutor[votingExecutorInv[_votingExecutor]] != _votingExecutor) {
            votingExecutorInv[_votingExecutor] = votingExecutor.length;
            votingExecutor.push(_votingExecutor);
        } else {
            require(votingExecutorInv[_votingExecutor] != 0, "OSWAP: cannot reset main executor");
        }
        isVotingExecutor[_votingExecutor] = _bool;
        emit ParamSet2("votingExecutor", bytes32(bytes20(_votingExecutor)), bytes32(uint256(_bool ? 1 : 0)));
    }
    function initAdmin(address _admin) external onlyOwner {
        require(admin == address(0), "OSWAP: Already set");
        _setAdmin(_admin);
    }
    function setAdmin(address _admin) external onlyVoting {
        _setAdmin(_admin);
    }
    function _setAdmin(address _admin) internal {
        require(_admin != address(0), "OSWAP: Invalid admin");
        admin = _admin;
        emit ParamSet("admin", bytes32(bytes20(admin)));
    }
    function addVotingConfig(bytes32 name, uint256 minExeDelay, uint256 minVoteDuration, uint256 maxVoteDuration, uint256 minGovTokenToCreateVote, uint256 minQuorum) external onlyVoting {
        uint256 totalStake = trollRegistry.totalStake();
        require(minExeDelay > 0 && minExeDelay <= 604800, "OSWAP: Invalid minExeDelay");
        require(minVoteDuration < maxVoteDuration && minVoteDuration <= 604800, "OSWAP: Invalid voteDuration");
        require(minGovTokenToCreateVote <= totalStake, "OSWAP: Invalid minGovTokenToCreateVote");
        require(minQuorum <= totalStake, "OSWAP: Invalid minQuorum");

        VotingConfig storage config = votingConfigs[name];
        require(config.minExeDelay == 0, "OSWAP: Config already exists");

        config.minExeDelay = minExeDelay;
        config.minVoteDuration = minVoteDuration;
        config.maxVoteDuration = maxVoteDuration;
        config.minGovTokenToCreateVote = minGovTokenToCreateVote;
        config.minQuorum = minQuorum;
		votingConfigProfiles.push(name);
        emit AddVotingConfig(name, minExeDelay, minVoteDuration, maxVoteDuration, minGovTokenToCreateVote, minQuorum);
    }
    function setVotingConfig(bytes32 configName, bytes32 paramName, uint256 paramValue) external onlyVoting {
        uint256 totalStake = trollRegistry.totalStake();

        require(votingConfigs[configName].minExeDelay > 0, "OSWAP: Config not exists");
        if (paramName == "minExeDelay") {
            require(paramValue > 0 && paramValue <= 604800, "OSWAP: Invalid minExeDelay");
            votingConfigs[configName].minExeDelay = paramValue;
        } else if (paramName == "minVoteDuration") {
            require(paramValue < votingConfigs[configName].maxVoteDuration && paramValue <= 604800, "OSWAP: Invalid voteDuration");
            votingConfigs[configName].minVoteDuration = paramValue;
        } else if (paramName == "maxVoteDuration") {
            require(votingConfigs[configName].minVoteDuration < paramValue, "OSWAP: Invalid voteDuration");
            votingConfigs[configName].maxVoteDuration = paramValue;
        } else if (paramName == "minGovTokenToCreateVote") {
            require(paramValue <= totalStake, "OSWAP: Invalid minGovTokenToCreateVote");
            votingConfigs[configName].minGovTokenToCreateVote = paramValue;
        } else if (paramName == "minQuorum") {
            require(paramValue <= totalStake, "OSWAP: Invalid minQuorum");
            votingConfigs[configName].minQuorum = paramValue;
        }
        emit SetVotingConfig(configName, paramName, paramValue);
    }

    function allVotings() external view returns (address[] memory) {
        return votings;
    }
    function getVotingCount() external view returns (uint256) {
        return votings.length;
    }
    function getVotings(uint256 start, uint256 count) external view returns (address[] memory _votings) {
        if (start + count > votings.length) {
            count = votings.length - start;
        }
        _votings = new address[](count);
        for (uint256 i = 0; i < count ; i++) {
            _votings[i] = votings[start + i];
        }
    }

    function isVotingContract(address votingContract) external view returns (bool) {
        return votings[votingIdx[votingContract]] == votingContract;
    }

    function getNewVoteId() external onlyVotingRegistry returns (uint256) {
        voteCount++;
        return voteCount;
    }

    function newVote(address vote, bool isExecutiveVote) external onlyVotingRegistry {
        require(vote != address(0), "Governance: Invalid voting address");
        require(votings.length == 0 || votings[votingIdx[vote]] != vote, "Governance: Voting contract already exists");

        // close expired poll
        uint256 i = 0;
        while (i < votings.length) {
            OSWAP_VotingContract voting = OSWAP_VotingContract(votings[i]);
            if (voting.executeParamLength() == 0 && voting.voteEndTime() < block.timestamp) {
                _closeVote(votings[i]);
            } else {
                i++;
            }
        }

        votingIdx[vote] = votings.length;
        votings.push(vote);
        if (isExecutiveVote){
            emit NewVote(vote);
        } else {
            emit NewPoll(vote);
        }
    }

    function voted(bool poll, address account, uint256 option) external {
        require(votings[votingIdx[msg.sender]] == msg.sender, "Governance: Voting contract not exists");
        if (poll)
            emit Poll(account, msg.sender, option);
        else
            emit Vote(account, msg.sender, option);
    }

    function updateWeight(address account) external {
        for (uint256 i = 0; i < votings.length; i ++){
            OSWAP_VotingContract(votings[i]).updateWeight(account);
        }
    }

    function executed() external {
        require(votings[votingIdx[msg.sender]] == msg.sender, "Governance: Voting contract not exists");
        _closeVote(msg.sender);
        emit Executed(msg.sender);
    }

    function veto(address voting) external {
        require(msg.sender == admin, "OSWAP: Not from shutdown admin");
        OSWAP_VotingContract(voting).veto();
        _closeVote(voting);
        emit Veto(voting);
    }

    function closeVote(address vote) external {
        require(OSWAP_VotingContract(vote).executeParamLength() == 0, "Governance: Not a Poll");
        require(block.timestamp > OSWAP_VotingContract(vote).voteEndTime(), "Governance: Voting not ended");
        _closeVote(vote);
    }
    function _closeVote(address vote) internal {
        uint256 idx = votingIdx[vote];
        require(idx > 0 || votings[0] == vote, "Governance: Voting contract not exists");
        if (idx < votings.length - 1) {
            votings[idx] = votings[votings.length - 1];
            votingIdx[votings[idx]] = idx;
        }
        votingIdx[vote] = 0;
        votings.pop();
    }
}