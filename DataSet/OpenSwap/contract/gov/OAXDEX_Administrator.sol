// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import "./interfaces/IOAXDEX_Administrator.sol";
import "./interfaces/IOAXDEX_Governance.sol";
import "./interfaces/IOAXDEX_PausableFactory.sol";
import '../libraries/SafeMath.sol';

contract OAXDEX_Administrator is IOAXDEX_Administrator {
    using SafeMath for uint256;

    modifier onlyVoting() {
        require(IOAXDEX_Governance(governance).isVotingExecutor(msg.sender), "OAXDEX: Not from voting");
        _; 
    }
    modifier onlyShutdownAdmin() {
        require(admins[adminsIdx[msg.sender]] == msg.sender, "Admin: Not a shutdown admin");
        _; 
    }

    address public override immutable governance;

    uint256 public override maxAdmin;
    address[] public override admins;
    mapping (address => uint256) public override adminsIdx;

    mapping (address => mapping (address => bool)) public override vetoVotingVote;
    mapping (address => mapping (address => bool)) public override factoryShutdownVote;
    mapping (address => mapping (address => bool)) public override factoryRestartVote;
    mapping (address => mapping (address => bool)) public override pairShutdownVote;
    mapping (address => mapping (address => bool)) public override pairRestartVote;
    
    constructor(address _governance) public {
        governance = _governance;
    }

    function allAdmins() external override view returns (address[] memory) {
        return admins;
    }

    function setMaxAdmin(uint256 _maxAdmin) external override onlyVoting {
        maxAdmin = _maxAdmin;
        emit SetMaxAdmin(maxAdmin);
    }
    function addAdmin(address _admin) external override onlyVoting {
        require(admins.length.add(1) <= maxAdmin, "OAXDEX: Max shutdown admin reached");
        require(_admin != address(0), "OAXDEX: INVALID_SHUTDOWN_ADMIN");
        require(admins.length == 0 || admins[adminsIdx[_admin]] != _admin, "OAXDEX: already a shutdown admin");
         adminsIdx[_admin] = admins.length;
        admins.push(_admin);
        emit AddAdmin(_admin);
    }
    function removeAdmin(address _admin) external override onlyVoting {
        uint256 idx = adminsIdx[_admin];
        require(idx > 0 || admins[0] == _admin, "Admin: Shutdown admin not exists");

        if (idx < admins.length - 1) {
            admins[idx] = admins[admins.length - 1];
            adminsIdx[admins[idx]] = idx;
        }
        adminsIdx[_admin] = 0;
        admins.pop();
        emit RemoveAdmin(_admin);
    }

    function getVote(mapping (address => bool) storage map) private view returns (bool[] memory votes) {
        uint length = admins.length;
        votes = new bool[](length);
        for (uint256 i = 0 ; i < length ; i++) {
            votes[i] = map[admins[i]];
        }
    }
    function checkVote(mapping (address => bool) storage map) private view returns (bool){
        uint256 count = 0;
        uint length = admins.length;
        uint256 quorum = length >> 1;
        for (uint256 i = 0 ; i < length ; i++) {
            if (map[admins[i]]) {
                count++;
                if (count > quorum) {
                    return true;
                }
            }
        }
        return false;
    }
    function clearVote(mapping (address => bool) storage map) private {
        uint length = admins.length;
        for (uint256 i = 0 ; i < length ; i++) {
            map[admins[i]] = false;
        }
    }

    function vetoVoting(address votingContract, bool YorN) external override onlyShutdownAdmin {
        vetoVotingVote[votingContract][msg.sender] = YorN;
        emit VotedVeto(msg.sender, votingContract, YorN);
    }
    function getVetoVotingVote(address votingContract) external override view returns (bool[] memory votes) {
        return getVote(vetoVotingVote[votingContract]);
    }
    function executeVetoVoting(address votingContract) external override {
        require(checkVote(vetoVotingVote[votingContract]), "Admin: executeVetoVoting: Quorum not met");
        clearVote(vetoVotingVote[votingContract]);
        IOAXDEX_Governance(governance).veto(votingContract);
    }

    function factoryShutdown(address factory, bool YorN) external override onlyShutdownAdmin {
        factoryShutdownVote[factory][msg.sender] = YorN;
        emit VotedFactoryShutdown(msg.sender, factory, YorN);
    }
    function getFactoryShutdownVote(address factory) external override view returns (bool[] memory votes) {
        return getVote(factoryShutdownVote[factory]);
    }
    function executeFactoryShutdown(address factory) external override {
        require(checkVote(factoryShutdownVote[factory]), "Admin: executeFactoryShutdown: Quorum not met");
        clearVote(factoryShutdownVote[factory]);
        IOAXDEX_PausableFactory(factory).setLive(false);
    }

    function factoryRestart(address factory, bool YorN) external override onlyShutdownAdmin {
        factoryRestartVote[factory][msg.sender] = YorN;
        emit VotedFactoryRestart(msg.sender, factory, YorN);
    }
    function getFactoryRestartVote(address factory) external override view returns (bool[] memory votes) {
        return getVote(factoryRestartVote[factory]);
    }
    function executeFactoryRestart(address factory) external override {
        require(checkVote(factoryRestartVote[factory]), "Admin: executeFactoryRestart: Quorum not met");
        clearVote(factoryRestartVote[factory]);
        IOAXDEX_PausableFactory(factory).setLive(true);
    }

    function pairShutdown(address pair, bool YorN) external override onlyShutdownAdmin {
        pairShutdownVote[pair][msg.sender] = YorN;
        emit VotedPairShutdown(msg.sender, pair, YorN);
    }
    function getPairShutdownVote(address pair) external override view returns (bool[] memory votes) {
        return getVote(pairShutdownVote[pair]);
    }
    function executePairShutdown(address factory, address pair) external override {
        require(checkVote(pairShutdownVote[pair]), "Admin: executePairShutdown: Quorum not met");
        clearVote(pairShutdownVote[pair]);
        IOAXDEX_PausableFactory(factory).setLiveForPair(pair, false);
    }

    function pairRestart(address pair, bool YorN) external override onlyShutdownAdmin {
        pairRestartVote[pair][msg.sender] = YorN;
        emit VotedPairRestart(msg.sender, pair, YorN);
    }
    function getPairRestartVote(address pair) external override view returns (bool[] memory votes) {
        return getVote(pairRestartVote[pair]);
    }
    function executePairRestart(address factory, address pair) external override {
        require(checkVote(pairRestartVote[pair]), "Admin: executePairRestart: Quorum not met");
        clearVote(pairRestartVote[pair]);
        IOAXDEX_PausableFactory(factory).setLiveForPair(pair, true);
    }
}