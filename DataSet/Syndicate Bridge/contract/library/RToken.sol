// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IBridgeToken.sol";

library RToken {
    using SafeERC20 for IERC20;

    enum IssueType {
        DEFAULT,
        MINTABLE
    }

    struct Token {
        address addr;
        uint256 chainId;
        IssueType issueType;
        bool exist;
    }

    function unsafeTransfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(from.balance >= amount, "RT: INSUFFICIENT_BALANCE");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = to.call{value: amount}("");
        require(success, "RT: SEND_REVERT");
    }

    function enter(
        Token memory token,
        address from,
        address to,
        uint256 amount
    ) internal returns (Token memory) {
        require(token.exist, "RT: NOT_LISTED");
        if (token.issueType == IssueType.MINTABLE) {
            IBridgeToken(token.addr).burn(from, amount);
        } else if (token.issueType == IssueType.DEFAULT) {
            IERC20(token.addr).safeTransferFrom(from, to, amount);
        } else {
            assert(false);
        }
        return token;
    }

    function exit(
        Token memory token,
        address from,
        address to,
        uint256 amount
    ) internal returns (Token memory) {
        require(token.exist, "RT: NOT_LISTED");
        if (token.addr == address(0)) {
            unsafeTransfer(from, to, amount);
        } else if (token.issueType == IssueType.MINTABLE) {
            IBridgeToken(token.addr).mint(to, amount);
        } else if (token.issueType == IssueType.DEFAULT) {
            IERC20(token.addr).safeTransfer(to, amount);
        } else {
            assert(false);
        }
        return token;
    }
}
