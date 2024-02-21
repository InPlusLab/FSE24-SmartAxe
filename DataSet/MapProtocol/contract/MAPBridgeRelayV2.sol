// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interface/IWToken.sol";
import "./interface/IMAPToken.sol";
import "./interface/IFeeCenter.sol";
import "./utils/Role.sol";
import "./interface/IFeeCenter.sol";
import "./interface/IVault.sol";
import "./utils/TransferHelper.sol";

contract MAPBridgeRelayV2 is ReentrancyGuard, Role, Initializable, Pausable {
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
    mapping(address => uint) public transferFeeList;

    mapping(address => bool) public authToken;

    mapping(uint => mapping(address =>uint)) vaultBalance;

    IFeeCenter public feeCenter;

    event mapTransferOut(address indexed token, address indexed from, address indexed to,
        bytes32 orderId, uint amount, uint fromChain, uint toChain);
    event mapTransferIn(address indexed token, address indexed from, address indexed to,
        bytes32 orderId, uint amount, uint fromChain, uint toChain);
    event mapTokenRegister(bytes32 tokenID, address token);
    event mapDepositIn(address indexed token, address indexed from, address indexed to,
        bytes32 orderId, uint amount, uint fromChain);

    function initialize(address _wToken, address _mapToken) public initializer {
        uint _chainId;
        assembly {_chainId := chainid()}
        selfChainId = _chainId;
        wToken = _wToken;
        mapToken = IERC20(_mapToken);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    receive() external payable {
        require(msg.sender == wToken, "only wToken");
    }


    modifier checkOrder(bytes32 orderId) {
        require(!orderList[orderId], "order exist");
        orderList[orderId] = true;
        _;
    }

    function setPause() external onlyManager {
        _pause();
    }

    function setUnpause() external onlyManager {
        _unpause();
    }

    function getOrderID(address token, address from, address to, uint amount, uint toChainID) public returns (bytes32){
        return keccak256(abi.encodePacked(nonce++, from, to, token, amount, selfChainId, toChainID));
    }

    function setFeeCenter(address fee) external onlyManager {
        feeCenter = IFeeCenter(fee);
    }

    function addAuthToken(address[] memory token) external onlyManager {
        for (uint i = 0; i < token.length; i++) {
            authToken[token[i]] = true;
        }
    }

    function removeAuthToken(address[] memory token) external onlyManager {
        for (uint i = 0; i < token.length; i++) {
            authToken[token[i]] = false;
        }
    }

    function checkAuthToken(address token) internal view returns (bool) {
        return authToken[token];
    }

    function getFeeValue(uint amount, uint rate) pure public returns (uint){
        return amount.mul(rate).div(10000);
    }

    function collectChainFee(uint amount, address token) public {
        address transferToken = token;
        if (token == address(0)) {
            transferToken = wToken;
        }
        if (amount > 0) {
            (address feeToken,uint rate) = feeCenter.getDistribute(0, token);
            uint out = getFeeValue(amount, rate);
            TransferHelper.safeTransfer(transferToken, feeToken, out);

            (feeToken, rate) = feeCenter.getDistribute(1, token);
            out = getFeeValue(amount, rate);
            TransferHelper.safeTransfer(transferToken, feeToken, out);
        }
    }

    function setVaultValue(uint amount,uint fromChain,uint toChain,address token)internal {
        vaultBalance[fromChain][token] += amount;
        vaultBalance[toChain][token] -=amount;
    }


    function getChainFee(uint toChainId, address token, uint amount) public view returns (uint out){
        if (token == address(0)) {
            token = wToken;
        }
        return feeCenter.getTokenFee(toChainId, token, amount);
    }

    function transferOut(address token, address to, uint amount, uint toChainId) external whenNotPaused {
        require(IERC20(token).balanceOf(msg.sender) >= amount, "balance too low");
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);
        uint fee = getChainFee(toChainId, token, amount);
        uint outAmount = amount.sub(fee);
        if (checkAuthToken(token)) {
            IMAPToken(token).burn(outAmount);
        }
        collectChainFee(fee, token);
        transferFeeList[token] = transferFeeList[token].add(amount).sub(outAmount);
        bytes32 orderId = getOrderID(token, msg.sender, to, outAmount, toChainId);
        setVaultValue(amount,selfChainId,toChainId,token);
        emit mapTransferOut(token, msg.sender, to, orderId, outAmount, selfChainId, toChainId);
    }

    function transferOutNative(address to, uint toChainId) external payable whenNotPaused {
        uint amount = msg.value;
        require(amount > 0, "value too low");
        IWToken(wToken).deposit{value : amount}();
        uint fee = getChainFee(toChainId, address(0), amount);
        uint outAmount = amount.sub(fee);
        collectChainFee(fee, address(0));
        transferFeeList[address(0)] = transferFeeList[address(0)].add(amount).sub(outAmount);
        bytes32 orderId = getOrderID(address(0), msg.sender, to, outAmount, toChainId);
        setVaultValue(amount,selfChainId,toChainId,address(0));
        emit mapTransferOut(address(0), msg.sender, to, orderId, outAmount, selfChainId, toChainId);
    }

    function transferIn(address token, address from, address payable to, uint amount, bytes32 orderId, uint fromChain, uint toChain)
    external checkOrder(orderId) nonReentrant onlyManager whenNotPaused{
        uint fee = getChainFee(toChain, token, amount);
        uint outAmount = amount.sub(fee);
        if (toChain == selfChainId) {
            if (token == address(0)) {
                TransferHelper.safeWithdraw(wToken, outAmount);
                TransferHelper.safeTransferETH(to, outAmount);
            } else if (checkAuthToken(token)) {
                IMAPToken(token).mint(address(this), amount);
                TransferHelper.safeTransfer(token, to, amount);
            } else {
                require(IERC20(token).balanceOf(address(this)) >= amount, "balance too low");
                TransferHelper.safeTransfer(token, to, outAmount);
            }
            collectChainFee(fee, token);
            emit mapTransferIn(address(0), from, to, orderId, outAmount, fromChain, toChain);
        } else {
            if (checkAuthToken(token)) {
                IMAPToken(token).burn(outAmount);
            }
            emit mapTransferOut(token, from, to, orderId, outAmount, fromChain, toChain);
        }
        setVaultValue(amount,fromChain,toChain,token);
    }

    function depositIn(address token, address from, address payable to, uint amount, bytes32 orderId, uint fromChain)
    external payable checkOrder(orderId) nonReentrant onlyManager whenNotPaused{
        if (token == address(0)){
            IWToken(wToken).deposit{value : amount}();
            token == wToken;
        }
        address vaultTokenAddress = feeCenter.getVaultToken(token);
        require(vaultTokenAddress != address(0), "only vault token");
        IVault vaultToken = IVault(vaultTokenAddress);
        IERC20(token).transfer(vaultTokenAddress, amount);
        vaultToken.stakingTo(amount, to);
        vaultBalance[fromChain][token]+=amount;
        emit mapDepositIn(token, from, to, orderId, amount, fromChain);
    }


    function withdraw(address token, address payable receiver, uint256 amount) public onlyManager {
        if (token == address(0)) {
            IWToken(wToken).withdraw(amount);
            receiver.transfer(amount);
        } else {
            IERC20(token).transfer(receiver, amount);
        }
    }
}