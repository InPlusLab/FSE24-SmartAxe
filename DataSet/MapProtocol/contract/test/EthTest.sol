// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IWToken {
    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function withdraw(uint) external ;
}

contract EthTest{
    function initialize(address _wToken,address _mapToken) public{
    }

    receive() external payable{
    }

    function transferOutNative(uint amount) external payable  {
        IWToken(0xf70949Bc9B52DEFfCda63B0D15608d601e3a7C49).deposit{value : amount}();
    }

    function transferInNative(address payable to, uint amount) external{
        IWToken(0xf70949Bc9B52DEFfCda63B0D15608d601e3a7C49).withdraw(amount);
        TransferHelper.safeTransferETH(to,amount);
    }
}

library TransferHelper {
    function safeWithdraw(address wtoken,uint value)internal{
        (bool success, bytes memory data) = wtoken.call(abi.encodeWithSelector(0x2e1a7d4d,value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: WiTHDRAW_FAILED');
    }

    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}