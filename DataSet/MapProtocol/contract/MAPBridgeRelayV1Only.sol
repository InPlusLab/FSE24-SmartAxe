// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";


interface IWToken {
    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function withdraw(uint) external;
}


interface IMAPToken {
    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;

    function burnFrom(address from, uint256 amount) external;
}


contract Role is AccessControl{
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    constructor(){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    modifier onlyManager(){
        require(hasRole(MANAGER_ROLE, msg.sender), "Caller is not a manager");
        _;
    }

    function addManager(address manager) external onlyRole(DEFAULT_ADMIN_ROLE){
        _setupRole(MANAGER_ROLE, manager);
    }
}

contract MAPBridgeRelayV1Only is ReentrancyGuard,Role,Initializable{
    using SafeMath for uint;

    uint public nonce;

    IERC20 public mapToken;
    address public wToken;          // native wrapped token

    uint public selfChainId;

    mapping(bytes32 => address) public tokenRegister;
    //Gas transfer fee charged by the target chain
    mapping(uint => uint) public chainGasFee;
    mapping(bytes32 => bool) orderList;

    uint public chainGasFees;


    uint public transferFee;    // tranfer fee for every token, one in a million
    mapping (address => uint) public transferFeeList;


    event mapTransferOut(address indexed token, address indexed from, address indexed to,
        bytes32 orderId, uint amount, uint fromChain, uint toChain);
    event mapTransferIn(address indexed token, address indexed from, address indexed to,
        bytes32 orderId, uint amount, uint fromChain, uint toChain);
    event mapTokenRegister(bytes32 tokenID, address token);

    function initialize(address _wToken,address _mapToken) public initializer{
        uint _chainId;
        assembly {_chainId := chainid()}
        selfChainId = _chainId;
        wToken = _wToken;
        mapToken = IERC20(_mapToken);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    receive() external payable{
        require(msg.sender == wToken,"only wToken");
    }


    modifier checkOrder(bytes32 orderId) {
        require(!orderList[orderId], "order exist");
        orderList[orderId] = true;
        _;
    }

    modifier checkBalance(address token, address sender,uint amount){
        require(IERC20(token).balanceOf(sender) >= amount,"balance too low");
        _;
    }

    function getTokenId(address token) internal view returns (bytes32){
        return keccak256(abi.encodePacked(IERC20Metadata(token).name()));
    }

    function getTokenIdForName(string memory name) internal pure returns (bytes32){
        return keccak256(abi.encodePacked(name));
    }

    function getOrderID(address token, address from, address to, uint amount, uint toChainID) public returns (bytes32){
        return keccak256(abi.encodePacked(nonce++, from, to, token, amount, selfChainId, toChainID));
    }

    function register(address token, string memory name) public onlyManager{
        bytes32 id;
        if (bytes(name).length > 0) {
            id = getTokenIdForName(name);
        } else {
            id = getTokenId(token);
        }
        tokenRegister[id] = token;
        emit mapTokenRegister(id, token);
    }


    function setTransferFee(uint fee) external onlyManager {
        require(fee <= 1000000, "Transfer fee percentage max 1000000");
        transferFee = fee;
    }

    function getAmountWithdraw(uint amount) public view returns (uint){
        if (transferFee == 0) {
            return amount;
        } else {
            return amount.mul(uint(1000000).sub(transferFee)).div(1000000);
        }
    }

    function collectChainFee(uint toChainId,uint native) internal{
        uint cFee = chainGasFee[toChainId];
        if (cFee > 0) {
            require(msg.value >= cFee.add(native),"balance too low");
            IWToken(wToken).deposit{value : msg.value.sub(native)}();
        }
    }

    function transferOutTokenBurn(address token, address to, uint amount, uint toChainId) external payable
    checkBalance(token,msg.sender,amount)  {
        TransferHelper.safeTransferFrom(token,msg.sender,address(this),amount);
        collectChainFee(toChainId,0);
        uint outAmount = getAmountWithdraw(amount);
        transferFeeList[token] = transferFeeList[token].add(amount).sub(outAmount);
        IMAPToken(token).burn(outAmount);
        bytes32 orderId = getOrderID(token, msg.sender, to, outAmount, toChainId);
        emit mapTransferOut(token, msg.sender, to, orderId, outAmount, selfChainId, toChainId);
    }


    function transferOutToken(address token, address to, uint amount, uint toChainId) external payable
    checkBalance(token,msg.sender,amount)  {
        TransferHelper.safeTransferFrom(token,msg.sender,address(this),amount);
        collectChainFee(toChainId,0);
        uint outAmount = getAmountWithdraw(amount);
        transferFeeList[token] = transferFeeList[token].add(amount).sub(outAmount);
        bytes32 orderId = getOrderID(token, msg.sender, to, outAmount, toChainId);
        emit mapTransferOut(token, msg.sender, to, orderId, outAmount, selfChainId, toChainId);
    }

    function transferOutNative(address to, uint amount, uint toChainId) external payable{
        IWToken(wToken).deposit{value : amount}();
        collectChainFee(toChainId,amount);
        uint outAmount = getAmountWithdraw(amount);
        transferFeeList[address(0)] = transferFeeList[address(0)].add(amount).sub(outAmount);
        bytes32 orderId = getOrderID(address(0), msg.sender, to, outAmount, toChainId);
        emit mapTransferOut(address(0), msg.sender, to, orderId, outAmount, selfChainId, toChainId);
    }


    function transferInToken(address token, address from, address payable to, uint amount, bytes32 orderId, uint fromChain, uint toChain)
    external checkOrder(orderId) nonReentrant onlyManager{
        uint outAmount = getAmountWithdraw(amount);
        if (toChain == selfChainId) {
            require(IERC20(token).balanceOf(address(this)) >= amount,"balance too low");
            TransferHelper.safeTransfer(token,to,amount);
            emit mapTransferIn(token, from, to, orderId, outAmount, fromChain, toChain);
        }else{
            emit mapTransferOut(token, from, to, orderId, outAmount, fromChain, toChain);
        }
    }

    function transferInTokenMint(address token, address from, address payable to, uint amount, bytes32 orderId, uint fromChain, uint toChain)
    external checkOrder(orderId) nonReentrant  onlyManager{
        IMAPToken(token).mint(address(this), amount);
        uint outAmount = getAmountWithdraw(amount);
        if (toChain == selfChainId){
            TransferHelper.safeTransfer(token,to,amount);
            emit mapTransferIn(token, from, to, orderId, outAmount, fromChain, toChain);
        }else{
            IMAPToken(token).burn(outAmount);
            emit mapTransferOut(token, from, to, orderId, outAmount, fromChain, toChain);
        }
    }

    function transferInNative(address from, address payable to, uint amount, bytes32 orderId, uint fromChain, uint toChain)
    external checkOrder(orderId) nonReentrant onlyManager{
        uint outAmount = getAmountWithdraw(amount);
        if (toChain == selfChainId){
            require(IERC20(wToken).balanceOf(address(this)) >= amount,"balance too low");
            TransferHelper.safeWithdraw(wToken,amount);
            TransferHelper.safeTransferETH(to,amount);
            emit mapTransferIn(address(0), from, to, orderId, outAmount, fromChain, toChain);
        }else{
            emit mapTransferOut(address(0), from, to, orderId, outAmount, fromChain, toChain);
        }
    }

    function setChainFee(uint chainId, uint fee) external  onlyManager{
        chainGasFee[chainId] = fee;
    }

    function withdraw(address token, address payable receiver,uint256 amount) public onlyManager{
        if(token == address(0)){
            IWToken(wToken).withdraw(amount);
            receiver.transfer(amount);
        }else{
            IERC20(token).transfer(receiver,amount);
        }
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