// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

interface ISyntFabric {
    function getRealRepresentation(address _syntTokenAdr)
        external
        view
        returns (address);

    function getSyntRepresentation(address _realTokenAdr, uint256 _chainID)
        external
        view
        returns (address);

    function synthesize(
        address _to,
        uint256 _amount,
        address _stoken
    ) external;

    function unsynthesize(
        address _to,
        uint256 _amount,
        address _stoken
    ) external;
}
