// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

interface IOAXDEX_VotingExecutor {
    function execute(bytes32[] calldata params) external;
}
