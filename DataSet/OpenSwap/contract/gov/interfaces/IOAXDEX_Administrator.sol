// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

interface IOAXDEX_Administrator {

    event SetMaxAdmin(uint256 maxAdmin);
    event AddAdmin(address admin);
    event RemoveAdmin(address admin);

    event VotedVeto(address indexed admin, address indexed votingContract, bool YorN);
    event VotedFactoryShutdown(address indexed admin, address indexed factory, bool YorN);
    event VotedFactoryRestart(address indexed admin, address indexed factory, bool YorN);
    event VotedPairShutdown(address indexed admin, address indexed pair, bool YorN);
    event VotedPairRestart(address indexed admin, address indexed pair, bool YorN);

    function governance() external view returns (address);
    function allAdmins() external view returns (address[] memory);
    function maxAdmin() external view returns (uint256);
    function admins(uint256) external view returns (address);
    function adminsIdx(address) external view returns (uint256);

    function vetoVotingVote(address, address) external view returns (bool);
    function factoryShutdownVote(address, address) external view returns (bool);
    function factoryRestartVote(address, address) external view returns (bool);
    function pairShutdownVote(address, address) external view returns (bool);
    function pairRestartVote(address, address) external view returns (bool);

    function setMaxAdmin(uint256 _maxAdmin) external;
    function addAdmin(address _admin) external;
    function removeAdmin(address _admin) external;

    function vetoVoting(address votingContract, bool YorN) external;
    function getVetoVotingVote(address votingContract) external view returns (bool[] memory votes);
    function executeVetoVoting(address votingContract) external;

    function factoryShutdown(address factory, bool YorN) external;
    function getFactoryShutdownVote(address factory) external view returns (bool[] memory votes);
    function executeFactoryShutdown(address factory) external;
    function factoryRestart(address factory, bool YorN) external;
    function getFactoryRestartVote(address factory) external view returns (bool[] memory votes);
    function executeFactoryRestart(address factory) external;

    function pairShutdown(address pair, bool YorN) external;
    function getPairShutdownVote(address pair) external view returns (bool[] memory votes);
    function executePairShutdown(address factory, address pair) external;
    function pairRestart(address pair, bool YorN) external;
    function getPairRestartVote(address pair) external view returns (bool[] memory votes);
    function executePairRestart(address factory, address pair) external;
}