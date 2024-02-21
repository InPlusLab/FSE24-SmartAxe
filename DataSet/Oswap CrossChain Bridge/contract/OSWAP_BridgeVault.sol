// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IOSWAP_BridgeVault.sol";
import "./interfaces/IOSWAP_ConfigStore.sol";
import "./interfaces/IOSWAP_BridgeVaultTrollRegistry.sol";
import "./interfaces/IOSWAP_HybridRouter2.sol";
import "./interfaces/IOSWAP_SideChainTrollRegistry.sol";
import "./interfaces/IOSWAP_SwapPolicy.sol";

interface PriceOracle {
    function latestAnswer() external view returns (int256);
}

/*
From the Whitepaper:
There are 5 types of fee mechanisms:

Chain Fee:  This is a flat fee that will be collected and given to the troll assigned to be the Trx Creator to compensate for gas fees
Bridge Trx Fee:  This is a % of the transaction amount and it is this fee that will be split amongst the liquidity providers, trolls and the protocol
Balancer Fee:  The portion of a transaction that negatively unbalances a vault will be subjected to a balancer fee
Order Cancel & Withdraw Fee:  This is a fee that will be charged when an interchain user decides to cancel and withdraw funds from the order
LP Interchain Withdraw Fee:  This fee is for a phase 2 feature that will enable a Liquidity provider to withdraw their liquidity from a blockchain different from the one they staked on
*/

/*
                   -ve   |   +ve
       <-----------------|-------------->------------------> (lpAssetBalance + totalPendingWithdrawal)
         removeLiquidity | addLiquidity   swap(bridge_fee)
                  <------|---------->                        (imbalance)
                    swap | newOrder
     <-------------------|----------------->                 (protocolFeeBalance)
       withdrawlTrollFee | swap(troll_fee)

*/

contract OSWAP_BridgeVault is IOSWAP_BridgeVault, ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "value < 0");
        return uint256(value);
    }
    function toInt256(uint256 value) internal pure returns (int256) {
        require(value <= uint256(type(int256).max), "value > int256.max");
        return int256(value);
    }
    function _transferAssetFrom(address from, uint amount) internal returns (uint256 balance) {
        balance = asset.balanceOf(address(this));
        asset.safeTransferFrom(from, address(this), amount);
        balance = asset.balanceOf(address(this)) - balance;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    modifier whenNotPaused() {
        require(address(trollRegistry)==address(0)||(!trollRegistry.paused()), "PAUSED!");
        _;
    }

    address owner;

    IOSWAP_SideChainTrollRegistry public override trollRegistry;
    IERC20 public immutable override govToken;
    IERC20 public immutable override asset;
    int8 public immutable override assetDecimalsScale;
    IOSWAP_ConfigStore public override configStore;
    IOSWAP_BridgeVaultTrollRegistry public override vaultRegistry;

    int256 public override imbalance;
    uint256 public override lpAssetBalance;
    uint256 public override totalPendingWithdrawal;
    // protocol fee will be distributed off-chain
    uint256 public override protocolFeeBalance;

    mapping(address => uint256) public override pendingWithdrawalAmount; // pendingWithdrawalAmount[lp] = amount
    mapping(address => uint256) public override pendingWithdrawalTimeout; // pendingWithdrawalTimeout[lp] = timeout

    Order[] public override orders;
    mapping(uint256 => Order[]) public override orderAmendments;
    mapping(uint256 => address) public override orderOwner;
    mapping(uint256 => OrderStatus) public override orderStatus;
    mapping(uint256 => uint256) public override orderRefunds;
    // target chain
    mapping(bytes32 => OrderStatus) public override swapOrderStatus;

    constructor(IOSWAP_BridgeVaultTrollRegistry _vaultRegistry, IOSWAP_ConfigStore _configStore, IERC20 _asset) ERC20("OSWAP Bridge Vault", "OSWAP-VAULT") {
        // if vaultRegistry is not passed in, save msg.sender as the owner and set it afterwards
        if (address(_vaultRegistry) == address(0)) {
            owner = msg.sender;
        } else {
            vaultRegistry = _vaultRegistry;
            trollRegistry = vaultRegistry.trollRegistry();
        }
        IERC20 _govToken = _configStore.govToken();
        govToken = _govToken;
        uint8 govTokenDecimals = IERC20Metadata(address(_govToken)).decimals();
        asset = _asset;
        uint8 assetDecimals = IERC20Metadata(address(_asset)).decimals();
        assetDecimalsScale = int8(assetDecimals) - int8(govTokenDecimals);
        configStore = _configStore;
    }
    function initAddress(IOSWAP_BridgeVaultTrollRegistry _vaultRegistry) external override onlyOwner {
        require(address(_vaultRegistry) != address(0), "null address");
        require(address(vaultRegistry) == address(0), "already init");
        vaultRegistry = _vaultRegistry;
        trollRegistry = vaultRegistry.trollRegistry();
        owner = address(0);
    }

    function updateConfigStore() external override {
        IOSWAP_ConfigStore _configStore = configStore.newConfigStore();
        require(address(_configStore) != address(0), "Invalid config store");
        configStore = _configStore;
        emit UpdateConfigStore(configStore);
    }
    function updateTrollRegistry() external override {
        address _trollRegistry = trollRegistry.newTrollRegistry();
        require(_trollRegistry != address(0), "Invalid config store");
        trollRegistry = IOSWAP_SideChainTrollRegistry(_trollRegistry);
        emit UpdateTrollRegistry(trollRegistry);
    }

    function ordersLength() external view override returns (uint256 length) {
        length = orders.length;
    }
    function orderAmendmentsLength(uint256 orderId) external view override returns (uint256 length) {
        length = orderAmendments[orderId].length;
    }

    function getOrders(uint256 start, uint256 length) external view override returns (Order[] memory list) {
        Order[] memory accountOrders = orders;
        if (start < accountOrders.length) {
            if (start + length > accountOrders.length) {
                length = accountOrders.length - start;
            }
            list = new Order[](length);
            for (uint256 i = 0 ; i < length ; i++) {
                list[i] = accountOrders[i+start];
            }
        }
    }

    function lastKnownBalance() public view override returns (uint256 balance) {
        balance = toUint256(toInt256(lpAssetBalance + totalPendingWithdrawal + protocolFeeBalance) + imbalance);
    }

    /*
     * signatures related functions
     */
    function getChainId() public view override returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
    // Do not reuse the (chain,address,owner,orderId) combinations for other purpose
    // the order status should be checked and updated before and after applying the signatures respectively
    // otherwise a nonce should be added to the signature
    function hashCancelOrderParams(uint256 orderId, bool canceledByOrderOwner, uint256 protocolFee) public view override returns (bytes32) {
        return keccak256(abi.encodePacked(
            getChainId(),
            address(this),
            orderId,
            canceledByOrderOwner,
            protocolFee
        ));
    }
    function hashVoidOrderParams(bytes32 orderId) public view override returns (bytes32) {
        return keccak256(abi.encodePacked(
            getChainId(),
            address(this),
            orderId
        ));
    }
    function hashSwapParams(
        bytes32 orderId,
        uint256 amendment,
        Order calldata order,
        uint256 protocolFee,
        address[] calldata pair
    ) public view override returns (bytes32) {
        return keccak256(abi.encodePacked(
            getChainId(),
            address(this),
            orderId,
            amendment,
            order.inAmount,
            order.outToken,
            order.minOutAmount,
            protocolFee,
            pair,
            order.to,
            order.expire
        ));
    }
    function hashWithdrawParams(address _owner, uint256 amount, uint256 _nonce) public view override returns (bytes32) {
        return keccak256(abi.encodePacked(
            getChainId(),
            address(this),
            _owner,
            amount,
            _nonce
        ));
    }
    function hashOrder(address _owner, uint256 sourceChainId, uint256 orderId) public view override returns (bytes32){
        return keccak256(abi.encodePacked(_owner, getChainId(), address(this), sourceChainId, orderId));
    }

    /*
     * functions called by LP
     */
    function addLiquidity(uint256 amount) external override nonReentrant whenNotPaused {
        require(amount != 0, "amount must be greater than zero");
        amount = _transferAssetFrom(msg.sender, amount);
        uint256 mintAmount = lpAssetBalance == 0 ? amount : (amount * totalSupply() / lpAssetBalance);
        lpAssetBalance += amount;
        _mint(msg.sender, mintAmount);
        emit AddLiquidity(msg.sender, amount, mintAmount, balanceOf(msg.sender), lpAssetBalance);
    }
    function removeLiquidityRequest(uint256 lpTokenAmount) external override nonReentrant {
        uint256 assetAmount = lpTokenAmount * lpAssetBalance / totalSupply();
        require(lpAssetBalance >= assetAmount, "not enough fund");
        lpAssetBalance -= assetAmount;
        _burn(msg.sender, lpTokenAmount);

        uint256 delay = configStore.lpWithdrawlDelay();
        // if LP balance + imbalance (could be negative) enough to cover the withdrawal,
        // do the withdrawal right away
        if (delay == 0 && (toInt256(lpAssetBalance) + imbalance >= 0)) {
            asset.safeTransfer(msg.sender, assetAmount);
            emit RemoveLiquidity(msg.sender, assetAmount, totalPendingWithdrawal);
        } else {
            pendingWithdrawalAmount[msg.sender] += assetAmount;
            pendingWithdrawalTimeout[msg.sender] = block.timestamp + delay;
            totalPendingWithdrawal += assetAmount;
        }
        emit RemoveLiquidityRequest(msg.sender, assetAmount, lpTokenAmount, balanceOf(msg.sender), lpAssetBalance, totalPendingWithdrawal);
    }
    // can do remove withdrawal for others
    function removeLiquidity(address provider, uint256 assetAmount) external override nonReentrant {
        // check withdrawal timeout, burn vault token, return assets
        require(pendingWithdrawalTimeout[provider] <= block.timestamp, "BridgeVault: please wait");
        require(pendingWithdrawalAmount[provider] >= assetAmount, "BridgeVault: withdraw amount exceeded requested amount");
        pendingWithdrawalAmount[provider] -= assetAmount;
        totalPendingWithdrawal -= assetAmount;
        asset.safeTransfer(provider, assetAmount);
        emit RemoveLiquidity(provider, assetAmount, totalPendingWithdrawal);
    }

    /*
     *  new order on source chain
     */
    function _newOrder(Order memory order, address trader) internal returns (uint256 orderId) {
        orderId = orders.length;
        orders.push(order);
        orderStatus[orderId] = OrderStatus.Pending;
        imbalance += toInt256(order.inAmount);
        emit NewOrder(orderId, trader, order, imbalance);
        orderOwner[orderId] = trader;
    }

    /*
     *  functions called by proxy on source chain
     */
    function newOrderFromRouter(Order calldata order, address trader) external override whenNotPaused returns (uint256 orderId) {
        require(configStore.isApprovedProxy(msg.sender), "Not from approved address");
        require((asset.balanceOf(address(this))) >= order.inAmount + lastKnownBalance(), "insufficient amount");

        orderId = _newOrder(order, trader);
    }

    /*
     *  functions called by traders on source chain
     */
    function newOrder(Order memory order) external override nonReentrant whenNotPaused returns (uint256 orderId) {
        require(order.inAmount > 0, "input amount must be greater than zero");
        order.inAmount = _transferAssetFrom(msg.sender, order.inAmount);

        orderId = _newOrder(order, msg.sender);
    }
    function withdrawUnexecutedOrder(uint256 orderId) external override nonReentrant whenNotPaused {
        require(orderOwner[orderId] == msg.sender,  "BridgeVault: not from owner");
        require(orderStatus[orderId] == OrderStatus.RefundApproved, "BridgeVault: cancellation not approved");
        orderStatus[orderId] = OrderStatus.Cancelled;
        imbalance -= toInt256(orderRefunds[orderId]);
        asset.safeTransfer(msg.sender, orderRefunds[orderId]);
        emit WithdrawUnexecutedOrder(msg.sender, orderId, imbalance);
    }
    function requestAmendOrder(uint256 orderId, Order calldata order) external override nonReentrant whenNotPaused {
        require(orderOwner[orderId] == msg.sender, "BridgeVault: not from owner");
        require(orderStatus[orderId] == OrderStatus.Pending || orderStatus[orderId] == OrderStatus.RequestAmend, "BridgeVault: not a pending order");
        require(order.peerChain == orders[orderId].peerChain, "Invalid peerChain");
        require(order.inAmount == orders[orderId].inAmount, "Invalid in amount");

        if (orderAmendments[orderId].length == 0) {
            orderAmendments[orderId].push(orders[orderId]);
        }
        orderAmendments[orderId].push(order);
        orderStatus[orderId] = OrderStatus.RequestAmend;
        emit AmendOrderRequest(orderId, orderAmendments[orderId].length-1, order);
    }

    /*
     *  functions called by traders on target chain
     */
    function requestCancelOrder(uint256 sourceChainId, uint256 orderId) external override whenNotPaused {
        // order not exists on target chain !
        bytes32 _orderId = hashOrder(msg.sender, sourceChainId, orderId);
        require(swapOrderStatus[_orderId] == OrderStatus.NotSpecified, "BridgeVault: not a pending order");
        swapOrderStatus[_orderId] = OrderStatus.RequestCancel;
        emit RequestCancelOrder(msg.sender, sourceChainId, orderId, _orderId);
    }

    /*
     * troll helper functions
     */
    function assetPriceAgainstGovToken(address govTokenOracle, address assetTokenOracle) public view override returns (uint256 price) {
        uint256 govTokenPrice = toUint256(PriceOracle(govTokenOracle).latestAnswer());
        require(govTokenPrice != 0, "govToken has price of 0");
        uint256 _assetPrice =  toUint256(PriceOracle(assetTokenOracle).latestAnswer());
        require(_assetPrice != 0, "asset has price of 0");
        price = govTokenPrice * 1e18 / _assetPrice;
        if (assetDecimalsScale != 0) {
            price = assetDecimalsScale > 0 ? (price * (10**uint8(assetDecimalsScale))) : (price / (10**uint8(-assetDecimalsScale)));
        }
    }
    // for the (withdrawal) actions that require enough govToken to be staked, find all the trolls and their combined staked balance
    function _verifyStakedValue(bytes[] calldata signatures, bytes32 paramsHash, uint256 stakeRequired) internal returns (uint256[] memory signers, uint256 totalStake) {
        uint256 superTrollCount;
        (superTrollCount, totalStake, signers) = vaultRegistry.verifyStakedValue(msg.sender, signatures, paramsHash);
        require(totalStake >= stakeRequired || superTrollCount == trollRegistry.superTrollCount(), "BridgeVault: not enough stakes");
    }

    /*
     *  functions called by trolls on source chain
     */
    function cancelOrder(bytes[] calldata signatures, uint256 orderId, bool canceledByOrderOwner, uint256 protocolFee) external override whenNotPaused {
        Order storage order = orders[orderId];
        require(orderStatus[orderId] == OrderStatus.Pending || orderStatus[orderId] == OrderStatus.RequestAmend, "BridgeVault: cancel not requested");

        (/*swapPolicy*/,/*router*/,address govTokenOracle, address assetTokenOracle, uint256 baseFee,/*transactionFee*/) = configStore.getBridgeParams(asset);
        uint256 price = assetPriceAgainstGovToken(govTokenOracle, assetTokenOracle);
        (uint256[] memory signers, /*uint256 totalStake*/) = _verifyStakedValue(signatures, hashCancelOrderParams(orderId, canceledByOrderOwner, protocolFee), order.inAmount * 1e18 / price);

        uint256 refundAmount = orders[orderId].inAmount;

        // charge user
        uint256 fee;
        if (canceledByOrderOwner) {
            fee = baseFee + protocolFee;
            refundAmount -= fee;
            imbalance -= toInt256(fee);
            protocolFeeBalance += fee;
        }

        orderRefunds[orderId] = refundAmount;
        orderStatus[orderId] = OrderStatus.RefundApproved;

        emit OrderCanceled(orderId, msg.sender, signers, canceledByOrderOwner, imbalance, protocolFeeBalance);
    }

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
    ) external override nonReentrant whenNotPaused returns (uint256 amount) {
        bytes32 orderId = hashOrder(_owner, order.peerChain, _orderId);
        amount = order.inAmount;

        // swapOrderStatus[orderId] should not exist on target chain yet
        require(swapOrderStatus[orderId] == OrderStatus.NotSpecified,"BridgeVault: Order already processed");
        require(trollRegistry.isSuperTroll(msg.sender, true), "not a super troll");
        require(lastKnownBalance() >= amount, "BridgeVault: insufficient balance");

        address router;
        uint256 price;
        {
            uint256 fee;
            address govTokenOracle;
            address assetTokenOracle;
            uint256 baseFee;
            uint256 transactionFee; // lp's shares only
            IOSWAP_SwapPolicy swapPolicy;
            (swapPolicy, router, govTokenOracle, assetTokenOracle, baseFee, transactionFee) = configStore.getBridgeParams(asset);

            if (address(swapPolicy) != address(0)) {
                require(swapPolicy.allowToSwap(order), "swap policy not met");
            }

            transactionFee = amount * transactionFee / 1e18;
            fee = transactionFee + baseFee + protocolFee;
            require(amount > fee, "Input amount too small");
            imbalance -= toInt256(amount);
            lpAssetBalance += transactionFee;
            protocolFeeBalance += baseFee + protocolFee;
            price = assetPriceAgainstGovToken(govTokenOracle, assetTokenOracle);
            amount = amount - fee;
        }
        (uint256[] memory signers, /*uint256 totalStake*/) = _verifyStakedValue(signatures, hashSwapParams(orderId, amendment, order, protocolFee, pair), amount * 1e18 / price);

        swapOrderStatus[orderId] = OrderStatus.Executed;

        if (pair.length == 0) {
            require(address(asset) == order.outToken, "Invalid token");
            require(amount >= order.minOutAmount, "INSUFFICIENT_OUTPUT_AMOUNT");
            IERC20(order.outToken).safeTransfer(order.to, amount);
        } else {
            asset.safeIncreaseAllowance(address(router), amount);
            uint[] memory amounts;
            if (order.outToken == address(0)) {
                (/*address[] memory path*/, amounts) = IOSWAP_HybridRouter2(router).swapExactTokensForETH(amount, order.minOutAmount, pair, order.to, order.expire, "0x00");
            } else {
                address[] memory paths;
                (paths, amounts) = IOSWAP_HybridRouter2(router).swapExactTokensForTokens(amount, order.minOutAmount, pair, address(asset), order.to, order.expire, "0x00");
                require(paths[paths.length-1] == order.outToken,"BridgeVault: Token out not match");
            }
            amount = amounts[amounts.length-1];
        }

        emit Swap(_orderId, msg.sender, signers, _owner, amendment, order, amount, imbalance, lpAssetBalance, protocolFeeBalance);
    }

    function voidOrder(bytes[] calldata signatures, bytes32 orderId) external override {
        require(swapOrderStatus[orderId] == OrderStatus.NotSpecified,"BridgeVault: Order already processed");
        (uint256[] memory signers, /*uint256 totalStake*/) = _verifyStakedValue(signatures, hashVoidOrderParams(orderId), 0);
        swapOrderStatus[orderId] = OrderStatus.Cancelled;
        emit VoidOrder(orderId, msg.sender, signers);
    }

    /*
     * rebalancing
     */
    function rebalancerDeposit(uint256 assetAmount) external override nonReentrant {
        assetAmount = _transferAssetFrom(msg.sender, assetAmount);
        imbalance += toInt256(assetAmount);
        emit Rebalance(msg.sender, toInt256(assetAmount), imbalance);
    }
    function rebalancerWithdraw(bytes[] calldata signatures, uint256 assetAmount, uint256 _nonce) external override nonReentrant {
        (address rebalancer, address govTokenOracle, address assetTokenOracle) = configStore.getRebalanceParams(asset);
        uint256 price = assetPriceAgainstGovToken(govTokenOracle, assetTokenOracle);
        _verifyStakedValue(signatures, hashWithdrawParams(rebalancer, assetAmount, _nonce), assetAmount * 1e18 / price);
        imbalance -= toInt256(assetAmount);
        asset.safeTransfer(rebalancer, assetAmount);
        emit Rebalance(rebalancer, -toInt256(assetAmount), imbalance);
    }

    /*
     * anyone can call
     */
    function withdrawlTrollFee(uint256 amount) external override nonReentrant whenNotPaused {
        require(amount <= protocolFeeBalance, "amount exceeded fee total");
        protocolFeeBalance -= amount;
        address feeTo = configStore.feeTo();
        require(feeTo != address(0), "zero address");
        asset.safeTransfer(feeTo, amount);
        emit WithdrawlTrollFee(feeTo, amount, protocolFeeBalance);
    }
    function sync() external override {
        uint256 excess = asset.balanceOf(address(this)) - lastKnownBalance();
        protocolFeeBalance += excess;
        emit Sync(excess, protocolFeeBalance);
    }
}
