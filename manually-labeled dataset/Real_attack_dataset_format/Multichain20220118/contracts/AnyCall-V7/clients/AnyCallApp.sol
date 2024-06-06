pragma solidity ^0.8.0;

import "../../Administrable.sol";
import "../interfaces/IAnyCallProxyV7.sol";
import "../interfaces/IAnyCallApp.sol";
import "../interfaces/Types.sol";

abstract contract AnyCallApp is Administrable, IAnyCallApp {
    address public anyCallProxy;

    mapping(uint256 => mapping(address => bool)) public isApprovedSender;

    modifier onlyExecutor() {
        require(msg.sender == IAnyCallProxyV7(anyCallProxy).executor());
        _;
    }

    constructor(address anyCallProxy_) {
        anyCallProxy = anyCallProxy_;
    }

    function setSenders(
        uint256[] memory chainIDs,
        address[] memory senders,
        bool[] memory allow
    ) public onlyAdmin {
        for (uint256 i = 0; i < chainIDs.length; i++) {
            isApprovedSender[chainIDs[i]][senders[i]] = allow[i];
        }
    }

    function setAnyCallProxy(address proxy) public onlyAdmin {
        anyCallProxy = proxy;
    }

    function _anyExecute(
        uint256 fromChainID,
        address sender,
        bytes calldata data,
        uint256 callNonce
    ) internal virtual returns (bool success, bytes memory result);

    function anyExecute(
        uint256 fromChainId,
        address sender,
        bytes calldata data,
        uint256 callNonce
    )
        external
        override
        onlyExecutor
        returns (bool success, bytes memory result)
    {
        require(isApprovedSender[fromChainId][sender], "call not allowed");
        return _anyExecute(fromChainId, sender, data, callNonce);
    }

    function _anyCall(CallArgs memory _callArgs) internal {
        IAnyCallProxyV7(anyCallProxy).anyCall{value: msg.value}(_callArgs);
    }

    function _anyFallback(
        uint256 toChainId,
        address receiver,
        bytes calldata data,
        uint256 callNonce,
        bytes calldata reason
    ) internal virtual returns (bool success, bytes memory result);

    function anyFallback(
        uint256 toChainId,
        address receiver,
        bytes calldata data,
        uint256 callNonce,
        bytes calldata reason
    )
        external
        override
        onlyExecutor
        returns (bool success, bytes memory result)
    {
        require(
            msg.sender == IAnyCallProxyV7(anyCallProxy).executor(),
            "not allowed"
        );
        return _anyFallback(toChainId, receiver, data, callNonce, reason);
    }

    function depositAnyCallFee() public payable {
        IAnyCallProxyV7(anyCallProxy).deposit(address(this));
    }

    function withdrawAnyCallFee(uint256 amount) public onlyAdmin {
        uint256 ethAmount = IAnyCallProxyV7(anyCallProxy).withdraw(
            address(this),
            amount
        );
        (bool success, ) = admin.call{value: ethAmount}("");
        require(success);
    }

    function approve(uint256 execFeeAllowance_, uint256 recrFeeAllowance_)
        public
        onlyAdmin
    {
        IAnyCallProxyV7(anyCallProxy).approve(
            address(this),
            execFeeAllowance_,
            recrFeeAllowance_
        );
    }
}
