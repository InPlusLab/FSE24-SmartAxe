// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./Authorization.sol";
import "./OSWAP_VotingManager.sol";

contract OSWAP_ContractProxy is Authorization, ERC1967Proxy {

    // This is the keccak-256 hash of "eip1967.proxy.finalized" subtracted by 1
    bytes32 private constant _FINALIZED_SLOT = 0x8bb564a0863bb1e13757a10aadba40bc2510c2e7f716e75214c9c013269256d7;

    // we use the admin slot to store the voting manager address
    constructor(
        address _logic,
        address votingManager,
        bytes memory _data
    ) payable ERC1967Proxy(_logic, _data) {
        assert(_ADMIN_SLOT == bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1));
        _changeAdmin(votingManager);
        isPermitted[msg.sender] = true;
    }

    modifier authorizeUpgrade(address newImplementation) {
        require(OSWAP_VotingManager(_getAdmin()).isVotingExecutor(msg.sender) || isPermitted[msg.sender], "not auth");
        _;
    }

    function implementation() external view returns (address implementation_) {
        implementation_ = _implementation();
    }

    // also passing in the old address to ensure updating the correct contract
    function upgradeTo(address oldImplementation, address newImplementation, bool finalize) external authorizeUpgrade(newImplementation) {
        require(!StorageSlot.getBooleanSlot(_FINALIZED_SLOT).value, "finalized");
        require(oldImplementation == _implementation(), "invalid contract");
        _upgradeToAndCall(newImplementation, new bytes(0), false);
        if (finalize)
            StorageSlot.getBooleanSlot(_FINALIZED_SLOT).value = finalize;
    }

    function upgradeToAndCall(address oldImplementation, address newImplementation, bytes calldata data, bool finalize) external payable authorizeUpgrade(newImplementation) {
        require(!StorageSlot.getBooleanSlot(_FINALIZED_SLOT).value, "finalized");
        require(oldImplementation == _implementation(), "invalid contract");
        _upgradeToAndCall(newImplementation, data, true);
        if (finalize)
            StorageSlot.getBooleanSlot(_FINALIZED_SLOT).value = finalize;
    }
}