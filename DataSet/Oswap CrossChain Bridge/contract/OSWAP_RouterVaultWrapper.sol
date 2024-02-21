// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;


import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IOSWAP_BridgeVault.sol";
import "./interfaces/IOSWAP_HybridRouter2.sol";
import "./OSWAP_ConfigStore.sol";
import "./OSWAP_SideChainTrollRegistry.sol";

contract OSWAP_RouterVaultWrapper {
    using SafeERC20 for IERC20;

    modifier onlyEndUser() {
        require((tx.origin == msg.sender && !Address.isContract(msg.sender)), "Not from end user");
        _;
    }

    function _transferFrom(IERC20 token, address from, uint amount) internal returns (uint256 balance) {
        balance = token.balanceOf(address(this));
        token.safeTransferFrom(from, address(this), amount);
        balance = token.balanceOf(address(this)) - balance;
    }

    event UpdateConfigStore(OSWAP_ConfigStore newConfigStore);
    event Swap(address indexed vault, uint256 orderId, address sender, address inToken, uint256 inAmount);

    address public owner;

    OSWAP_ConfigStore public configStore;

    constructor() {
        owner = msg.sender;
    }
    function initAddress(OSWAP_ConfigStore _configStore) external {
        require(msg.sender == owner, "not from owner");
        require(address(_configStore) != address(0), "null address");
        require(address(configStore) == address(0), "already set");
        configStore = _configStore;
        owner = address(0);
    }

    function updateConfigStore() external {
        OSWAP_ConfigStore _configStore = configStore.newConfigStore();
        require(address(_configStore) != address(0), "Invalid config store");
        configStore = _configStore;
        emit UpdateConfigStore(configStore);
    }

    receive() external payable {
        require(msg.sender == configStore.router(), "not form router");
    }

    function swapExactTokensForTokens(address[] calldata pair, IOSWAP_BridgeVault vault, uint256 amountIn, uint256 deadline, IOSWAP_BridgeVault.Order memory order) external onlyEndUser returns (uint256 orderId) {
        // since we don't have a vault registry, we cannot lookup the vault from the bridge token, we pass the vault address instead
        address router = configStore.router();

        IERC20 inToken;
        {
        address[] memory path = IOSWAP_HybridRouter2(router).getPathOut(pair, address(vault.asset()));
        inToken = IERC20(path[0]);
        }
        amountIn = _transferFrom(inToken, msg.sender, amountIn);
        inToken.safeIncreaseAllowance(router, amountIn);

        (/*address[] memory path*/, uint256[] memory amounts) = IOSWAP_HybridRouter2(router).swapExactTokensForTokens(amountIn, order.inAmount, pair, address(inToken), address(vault), deadline, new bytes(0));
        order.inAmount = amounts[amounts.length-1];

        orderId = vault.newOrderFromRouter(order, msg.sender);
        emit Swap(address(vault), orderId, msg.sender, address(inToken), amounts[0]);
    }
    function swapTokensForExactTokens(address[] calldata pair, IOSWAP_BridgeVault vault, uint256 amountIn/*amountInMax*/, uint256 deadline, IOSWAP_BridgeVault.Order calldata order) external onlyEndUser returns (uint256 orderId) {
        IERC20 bridgeToken = vault.asset();
        address router = configStore.router();
        IERC20 inToken;
        {
        address[] memory path = IOSWAP_HybridRouter2(router).getPathOut(pair, address(bridgeToken));
        inToken = IERC20(path[0]);
        }
        amountIn = _transferFrom(inToken, msg.sender, amountIn);
        inToken.safeIncreaseAllowance(router, amountIn);

        (/*address[] memory path*/, uint256[] memory amounts) = IOSWAP_HybridRouter2(router).swapTokensForExactTokens(order.inAmount, amountIn, pair, address(bridgeToken), address(vault), deadline, new bytes(0));

        orderId = vault.newOrderFromRouter(order, msg.sender);
        emit Swap(address(vault), orderId, msg.sender, address(inToken), amounts[0]);
        // refund excessive amount back to user
        if (amountIn > amounts[0]) {
            inToken.safeTransfer(msg.sender, amountIn - amounts[0]);
            inToken.safeApprove(router, 0);
        }
    }
    function swapExactETHForTokens(address[] calldata pair, IOSWAP_BridgeVault vault, uint256 deadline, IOSWAP_BridgeVault.Order memory order) external payable onlyEndUser returns (uint256 orderId) {
        address router = configStore.router();

        // forward incoming ETH to router
        (/*address[] memory path*/, uint256[] memory amounts) = IOSWAP_HybridRouter2(router).swapExactETHForTokens{value:msg.value}(order.inAmount, pair, address(vault), deadline, new bytes(0));

        order.inAmount = amounts[amounts.length-1];

        orderId = vault.newOrderFromRouter(order, msg.sender);
        emit Swap(address(vault), orderId, msg.sender, address(0), amounts[0]);
    }
    function swapETHForExactTokens(address[] calldata pair, IOSWAP_BridgeVault vault, uint256 deadline, IOSWAP_BridgeVault.Order calldata order) external payable onlyEndUser returns (uint256 orderId) {
        address router = configStore.router();

        // forward incoming ETH to router
        (/*address[] memory path*/, uint256[] memory amounts) = IOSWAP_HybridRouter2(router).swapETHForExactTokens{value:msg.value}(order.inAmount, pair, address(vault), deadline, new bytes(0));

        orderId = vault.newOrderFromRouter(order, msg.sender);
        emit Swap(address(vault), orderId, msg.sender, address(0), amounts[0]);
        // refund excessive amount back to user
        safeTransferETH(msg.sender, msg.value - amounts[0]);
    }
    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}