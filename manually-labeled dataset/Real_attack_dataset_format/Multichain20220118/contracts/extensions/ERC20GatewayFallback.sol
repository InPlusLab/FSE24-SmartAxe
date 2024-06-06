pragma solidity ^0.8.1;

import "../AnyCallAppFallback.sol";
import "../ERC20Gateway.sol";
import "../interfaces/extensions/IERC20GatewayFallback.sol";

abstract contract ERC20GatewayFallback is ERC20Gateway, AnyCallAppFallback, IERC20GatewayFallback {
    
    function _swapoutFallback(uint256 amount, address sender, uint256 swapoutSeq) internal virtual returns (bool);

    function Swapout(uint256 amount, address receiver, uint256 destChainID) external payable returns (uint256) {
        require(_swapout(amount, msg.sender));
        swapoutSeq++;
        bytes memory data = abi.encode(amount, msg.sender, receiver, swapoutSeq);
        _anyCall(peer[destChainID], data, address(this), destChainID);
        emit LogAnySwapOut(amount, msg.sender, receiver, destChainID, swapoutSeq);
        return swapoutSeq;
    }

    function _anyFallback(bytes calldata data) internal override {
        (uint256 amount, address sender, , uint256 swapoutSeq) = abi.decode(
            data,
            (uint256, address, address, uint256)
        );
        require(_swapoutFallback(amount, sender, swapoutSeq));
    }
}