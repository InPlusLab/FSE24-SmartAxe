// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

interface IAuthorization {
    function owner() external view returns (address owner);
    function newOwner() external view returns (address newOwner);

    function isPermitted(address) external view returns (bool isPermitted);

    event Authorize(address user);
    event Deauthorize(address user);
    event StartOwnershipTransfer(address user);
    event TransferOwnership(address user);

    function transferOwnership(address newOwner_) external;
    function takeOwnership() external;
    function permit(address user) external;
    function deny(address user) external;
}
