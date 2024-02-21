// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./IOSWAP_BridgeVaultTrollRegistry.sol";
import "./IOSWAP_ConfigStore.sol";
import "./IOSWAP_SideChainTrollRegistry.sol";

interface IOSWAP_BridgeVault is IERC20, IERC20Metadata {

    event AddLiquidity(address indexed provider, uint256 amount, uint256 mintAmount, uint256 newBalance, uint256 newLpAssetBalance);
    event RemoveLiquidityRequest(address indexed provider, uint256 amount, uint256 burnAmount, uint256 newBalance, uint256 newLpAssetBalance, uint256 newPendingWithdrawal);
    event RemoveLiquidity(address indexed provider, uint256 amount, uint256 newPendingWithdrawal);
    event NewOrder(uint256 indexed orderId, address indexed owner, Order order, int256 newImbalance);
    event WithdrawUnexecutedOrder(address indexed owner, uint256 orderId, int256 newImbalance);
    event AmendOrderRequest(uint256 indexed orderId, uint256 indexed amendment, Order order);
    event RequestCancelOrder(address indexed owner, uint256 indexed sourceChainId, uint256 indexed orderId, bytes32 hashedOrderId);
    event OrderCanceled(uint256 indexed orderId, address indexed sender, uint256[] signers, bool canceledByOrderOwner, int256 newImbalance, uint256 newProtocolFeeBalance);
    event Swap(uint256 indexed orderId, address indexed sender, uint256[] signers, address owner, uint256 amendment, Order order, uint256 outAmount, int256 newImbalance, uint256 newLpAssetBalance, uint256 newProtocolFeeBalance);
    event VoidOrder(bytes32 indexed orderId, address indexed sender, uint256[] signers);
    event UpdateConfigStore(IOSWAP_ConfigStore newConfigStore);
    event UpdateTrollRegistry(IOSWAP_SideChainTrollRegistry newTrollRegistry);
    event Rebalance(address rebalancer, int256 amount, int256 newImbalance);
    event WithdrawlTrollFee(address feeTo, uint256 amount, uint256 newProtocolFeeBalance);
    event Sync(uint256 excess, uint256 newProtocolFeeBalance);

    // pending must be the init status which have value of 0
    enum OrderStatus{NotSpecified, Pending, Executed, RequestCancel, RefundApproved, Cancelled, RequestAmend}

    function trollRegistry() external view returns (IOSWAP_SideChainTrollRegistry trollRegistry);
    function govToken() external view returns (IERC20 govToken);
    function asset() external view returns (IERC20 asset);
    function assetDecimalsScale() external view returns (int8 assetDecimalsScale);
    function configStore() external view returns (IOSWAP_ConfigStore configStore);
    function vaultRegistry() external view returns (IOSWAP_BridgeVaultTrollRegistry vaultRegistry);
    function imbalance() external view returns (int256 imbalance);
    function lpAssetBalance() external view returns (uint256 lpAssetBalance);
    function totalPendingWithdrawal() external view returns (uint256 totalPendingWithdrawal);
    function protocolFeeBalance() external view returns (uint256 protocolFeeBalance);
    function pendingWithdrawalAmount(address liquidityProvider) external view returns (uint256 pendingWithdrawalAmount);
    function pendingWithdrawalTimeout(address liquidityProvider) external view returns (uint256 pendingWithdrawalTimeout);

    // source chain
    struct Order {
        uint256 peerChain;
        uint256 inAmount;
        address outToken;
        uint256 minOutAmount;
        address to;
        uint256 expire;
    }
    // source chain
    function orders(uint256 orderId) external view returns (uint256 peerChain, uint256 inAmount, address outToken, uint256 minOutAmount, address to, uint256 expire);
    function orderAmendments(uint256 orderId, uint256 amendment) external view returns (uint256 peerChain, uint256 inAmount, address outToken, uint256 minOutAmount, address to, uint256 expire);
    function orderOwner(uint256 orderId) external view returns (address orderOwner);
    function orderStatus(uint256 orderId) external view returns (OrderStatus orderStatus);
    function orderRefunds(uint256 orderId) external view returns (uint256 orderRefunds);
    // target chain
    function swapOrderStatus(bytes32 orderHash) external view returns (OrderStatus swapOrderStatus);

    function initAddress(IOSWAP_BridgeVaultTrollRegistry _vaultRegistry) external;
    function updateConfigStore() external;
    function updateTrollRegistry() external;
    function ordersLength() external view returns (uint256 length);
    function orderAmendmentsLength(uint256 orderId) external view returns (uint256 length);

    function getOrders(uint256 start, uint256 length) external view returns (Order[] memory list);

    function lastKnownBalance() external view returns (uint256 balance);

    /*
     * signatures related functions
     */
    function getChainId() external view returns (uint256 chainId);
    function hashCancelOrderParams(uint256 orderId, bool canceledByOrderOwner, uint256 protocolFee) external view returns (bytes32);
    function hashVoidOrderParams(bytes32 orderId) external view returns (bytes32);
    function hashSwapParams(
        bytes32 orderId,
        uint256 amendment,
        Order calldata order,
        uint256 protocolFee,
        address[] calldata pair
    ) external view returns (bytes32);
    function hashWithdrawParams(address _owner, uint256 amount, uint256 _nonce) external view returns (bytes32);
    function hashOrder(address _owner, uint256 sourceChainId, uint256 orderId) external view returns (bytes32);

    /*
     * functions called by LP
     */
    function addLiquidity(uint256 amount) external;
    function removeLiquidityRequest(uint256 lpTokenAmount) external;
    function removeLiquidity(address provider, uint256 assetAmount) external;

    /*
     *  functions called by traders on source chain
     */
    function newOrder(Order memory order) external returns (uint256 orderId);
    function withdrawUnexecutedOrder(uint256 orderId) external;
    function requestAmendOrder(uint256 orderId, Order calldata order) external;

    /*
     *  functions called by traders on target chain
     */
    function requestCancelOrder(uint256 sourceChainId, uint256 orderId) external;

    /*
     * troll helper functions
     */
    function assetPriceAgainstGovToken(address govTokenOracle, address assetTokenOracle) external view returns (uint256 price);

    /*
     *  functions called by trolls on source chain
     */
    function cancelOrder(bytes[] calldata signatures, uint256 orderId, bool canceledByOrderOwner, uint256 protocolFee) external;

    /*
     *  functions called by trolls on target chain
     */
    function swap(
        bytes[] calldata signatures,
        address _owner,
        uint256 _orderId,
        uint256 amendment,
        uint256 protocolFee,
        address[] calldata pair,
        Order calldata order
    ) external returns (uint256 amount);
    function voidOrder(bytes[] calldata signatures, bytes32 orderId) external;

    function newOrderFromRouter(Order calldata order, address trader) external returns (uint256 orderId);

    /*
     * rebalancing
     */
    function rebalancerDeposit(uint256 assetAmount) external;
    function rebalancerWithdraw(bytes[] calldata signatures, uint256 assetAmount, uint256 _nonce) external;

    /*
     * anyone can call
     */
    function withdrawlTrollFee(uint256 amount) external;
    function sync() external;
}
