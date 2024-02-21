// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './interfaces/IOSWAP_RestrictedPair2.sol';
import '../interfaces/IERC20.sol';
import '../libraries/SafeMath.sol';
import '../libraries/Address.sol';
import './interfaces/IOSWAP_RestrictedFactory.sol';
import '../oracle/interfaces/IOSWAP_OracleFactory.sol';
import '../gov/interfaces/IOAXDEX_Governance.sol';
import './interfaces/IOSWAP_ConfigStore.sol';
import '../oracle/interfaces/IOSWAP_OracleAdaptor2.sol';
import '../commons/OSWAP_PausablePair.sol';

contract OSWAP_RestrictedPair2 is IOSWAP_RestrictedPair2, OSWAP_PausablePair {
    using SafeMath for uint256;

    uint256 constant FEE_BASE = 10 ** 5;
    uint256 constant WEI = 10**18;

    bytes32 constant FEE_PER_ORDER = "RestrictedPair.feePerOrder";
    bytes32 constant FEE_PER_TRADER = "RestrictedPair.feePerTrader";
    bytes32 constant MAX_DUR = "RestrictedPair.maxDur";
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    mapping(bool => uint256) public override counter;
    mapping(bool => Offer[]) public override offers;
    mapping(bool => mapping(uint256 =>uint256)) public override prepaidFeeBalance;
    mapping(bool => mapping(address => uint256[])) public override providerOfferIndex;

    mapping(bool => mapping(uint256 => address[])) public override approvedTrader;
    mapping(bool => mapping(uint256 => mapping(address => bool))) public override isApprovedTrader;
    mapping(bool => mapping(uint256 => mapping(address => uint256))) public override traderAllocation;
    mapping(bool => mapping(address => uint256[])) public override traderOffer;

    address public override immutable governance;
    address public override immutable whitelistFactory;
    address public override immutable restrictedLiquidityProvider;
    address public override immutable govToken;
    address public override immutable configStore;
    address public override token0;
    address public override token1;
    bool public override scaleDirection;
    uint256 public override scaler;

    uint256 public override lastGovBalance;
    uint256 public override lastToken0Balance;
    uint256 public override lastToken1Balance;
    uint256 public override protocolFeeBalance0;
    uint256 public override protocolFeeBalance1;
    uint256 public override feeBalance;

    constructor() public {
        (address _governance, address _whitelistFactory, address _restrictedLiquidityProvider, address _configStore) = IOSWAP_RestrictedFactory(msg.sender).getCreateAddresses();
        governance = _governance;
        whitelistFactory = _whitelistFactory;
        govToken = IOAXDEX_Governance(_governance).oaxToken();
        restrictedLiquidityProvider = _restrictedLiquidityProvider;
        configStore = _configStore;

        offers[true].push(Offer({
            provider: address(this),
            locked: true,
            allowAll: false,
            amount: 0,
            receiving: 0,
            restrictedPrice: 0,
            startDate: 0,
            expire: 0
        }));
        offers[false].push(Offer({
            provider: address(this),
            locked: true,
            allowAll: false,
            amount: 0,
            receiving: 0,
            restrictedPrice: 0,
            startDate: 0,
            expire: 0
        }));
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external override {
        require(msg.sender == factory, 'FORBIDDEN'); // sufficient check

        token0 = _token0;
        token1 = _token1;
        require(token0 < token1, "Invalid token pair order"); 
        address oracle = IOSWAP_RestrictedFactory(factory).oracles(token0, token1);
        require(oracle != address(0), "No oracle found");

        uint8 token0Decimals = IERC20(token0).decimals();
        uint8 token1Decimals = IERC20(token1).decimals();
        if (token0Decimals == token1Decimals) {
            scaler = 1;
        } else {
            scaleDirection = token1Decimals > token0Decimals;
            scaler = 10 ** uint256(scaleDirection ? (token1Decimals - token0Decimals) : (token0Decimals - token1Decimals));
        }
    }

    function getOffers(bool direction, uint256 start, uint256 length) external override view returns (uint256[] memory index, address[] memory provider, bool[] memory lockedAndAllowAll, uint256[] memory receiving, uint256[] memory amountAndPrice, uint256[] memory startDateAndExpire) {
        return _showList(0, address(0), direction, start, length);
    }

    function getLastBalances() external view override returns (uint256, uint256) {
        return (
            lastToken0Balance,
            lastToken1Balance
        );
    }
    function getBalances() public view override returns (uint256, uint256, uint256) {
        return (
            IERC20(govToken).balanceOf(address(this)),
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FAILED');
    }
    function _safeTransferFrom(address token, address from, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FROM_FAILED');
    }

    function _getMaxOut(bool direction, uint256 offerIdx, address trader) internal view returns (uint256 output) {
        output =  offers[direction][offerIdx].amount;
        if (!offers[direction][offerIdx].allowAll) {
            uint256 alloc = traderAllocation[direction][offerIdx][trader];
            output = alloc < output ? alloc : output;
        }
    }
    function _getAmountIn(address trader, bool direction, address oracle, uint256 offerIdx, uint256 requestOut) internal view returns (uint256 amountIn, uint256 amountOut, uint256 numerator, uint256 denominator) {
        bytes memory data2 = abi.encodePacked(offerIdx);
        (numerator, denominator) = IOSWAP_OracleAdaptor2(oracle).getRatio(direction ? token0 : token1, direction ? token1 : token0, 0, requestOut, trader, data2);
        amountIn = requestOut.mul(denominator);
        if (scaler > 1)
            amountIn = (direction != scaleDirection) ? amountIn.mul(scaler) : amountIn.div(scaler);
        amountIn = amountIn.div(numerator);

        amountOut = amountIn.mul(numerator);
        if (scaler > 1)
            amountOut = (direction == scaleDirection) ? amountOut.mul(scaler) : amountOut.div(scaler);
        amountOut = amountOut.div(denominator);
    }
    function _oneOutput(uint256 amountIn, address trader, bool direction, uint256 offerIdx, address oracle, uint256 tradeFee) internal view returns (uint256 amountInPlusFee, uint256 output, uint256 tradeFeeCollected, uint256 price) {
        output = _getMaxOut(direction, offerIdx, trader);

        uint256 numerator; uint256 denominator;
        (amountInPlusFee, output, numerator, denominator) = _getAmountIn(trader, direction, oracle, offerIdx, output);

        tradeFeeCollected = amountInPlusFee.mul(tradeFee).div(FEE_BASE.sub(tradeFee));
        amountInPlusFee = amountInPlusFee.add(tradeFeeCollected);

        // check if offer enough to cover whole input, recalculate output if not
        if (amountIn < amountInPlusFee) {
            amountInPlusFee = amountIn;
            amountIn = amountIn.mul(FEE_BASE-tradeFee).div(FEE_BASE);
            tradeFeeCollected = amountInPlusFee - amountIn;
            output = amountIn.mul(numerator);
            if (scaler > 1)
                output = (direction == scaleDirection) ? output.mul(scaler) : output.div(scaler);
            output = output.div(denominator);
        }
        price = numerator.mul(WEI).div(denominator);
    }
    function getAmountOut(address tokenIn, uint256 amountIn, address trader, bytes calldata /*data*/) external view override returns (uint256 amountOut) {
        require(amountIn > 0, 'INSUFFICIENT_INPUT_AMOUNT');
        (uint256[] memory list) = _decodeData(0x84);
        bool direction = token0 == tokenIn;
        (address oracle, uint256 tradeFee, )  = IOSWAP_RestrictedFactory(factory).checkAndGetOracleSwapParams(token0, token1);
        uint256 offerIdx;
        uint256 length = list.length;
        for (uint256 i = 0 ; i < length ; i++) {
            offerIdx = list[i];
            require(offerIdx <= counter[direction], "Offer not exist");
            require(offers[direction][offerIdx].allowAll || isApprovedTrader[direction][offerIdx][trader], "Not a approved trader");
            (uint256 amountInPlusFee, uint256 offerOut,,) = _oneOutput(amountIn, trader, direction, offerIdx, oracle, tradeFee);
            amountIn = amountIn.sub(amountInPlusFee);
            amountOut = amountOut.add(offerOut);
        }
        require(amountIn == 0, "Amount exceeds available fund");
    }
    function getAmountIn(address tokenOut, uint256 amountOut, address trader, bytes calldata /*data*/) external view override returns (uint256 amountIn) {
        require(amountOut > 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        (uint256[] memory list) = _decodeData(0x84);
        bool direction = tokenOut == token1;
        (address oracle, uint256 tradeFee,)  = IOSWAP_RestrictedFactory(factory).checkAndGetOracleSwapParams(token0, token1);
        uint256 length = list.length;
        uint256 offerIdx;
        for (uint256 i  ; i < length ; i++) {
            offerIdx = list[i];
            require(offerIdx <= counter[direction], "Offer not exist");
            require(offers[direction][offerIdx].allowAll || isApprovedTrader[direction][offerIdx][trader], "Not a approved trader");
            uint256 tmpInt/*=maxOut*/ = _getMaxOut(direction, offerIdx, trader);
            tmpInt/*=offerOut*/ = (amountOut > tmpInt) ? tmpInt : amountOut;
            (tmpInt/*=offerIn*/,offerIdx/*=output*/,,) = _getAmountIn(trader, direction, oracle, offerIdx, tmpInt/*=offerOut*/);
            amountOut = amountOut.sub(offerIdx/*=output*/);
            amountIn = amountIn.add(tmpInt/*=offerIn*/);
        }
        amountIn = amountIn.mul(FEE_BASE).div(FEE_BASE.sub(tradeFee)).add(1);
        require(amountOut == 0, "Amount exceeds available fund");
    }

    function getProviderOfferIndexLength(address provider, bool direction) external view override returns (uint256 length) {
        return providerOfferIndex[direction][provider].length;
    }
    function getTraderOffer(address trader, bool direction, uint256 start, uint256 length) external view override returns (uint256[] memory index, address[] memory provider, bool[] memory lockedAndAllowAll, uint256[] memory receiving, uint256[] memory amountAndPrice, uint256[] memory startDateAndExpire) {
        return _showList(1, trader, direction, start, length);
    }  

    function getProviderOffer(address _provider, bool direction, uint256 start, uint256 length) external view override returns (uint256[] memory index, address[] memory provider, bool[] memory lockedAndAllowAll, uint256[] memory receiving, uint256[] memory amountAndPrice, uint256[] memory startDateAndExpire) {
        return _showList(2, _provider, direction, start, length);
    }
    function _showList(uint256 listType, address who, bool direction, uint256 start, uint256 length) internal view returns (uint256[] memory index, address[] memory provider, bool[] memory lockedAndAllowAll, uint256[] memory receiving, uint256[] memory amountAndPrice, uint256[] memory startDateAndExpire) {
        uint256 tmpInt;
        uint256[] storage __list;
        if (listType == 0) {
            __list = providerOfferIndex[direction][address(0)];
            tmpInt = offers[direction].length;
        } else if (listType == 1) {
            __list = traderOffer[direction][who];
            tmpInt = __list.length;
        } else if (listType == 2) {
            __list = providerOfferIndex[direction][who];
            tmpInt = __list.length;
        } else {
            revert("Unknown list");
        }
        uint256 _listType = listType; // stack too deep
        Offer[] storage _list = offers[direction];
        if (start < tmpInt) {
            if (start.add(length) > tmpInt) {
                length = tmpInt.sub(start);
            }
            index = new uint256[](length);
            provider = new address[](length);
            receiving = new uint256[](length);
            tmpInt = length * 2;
            lockedAndAllowAll = new bool[](tmpInt);
            amountAndPrice = new uint256[](tmpInt);
            startDateAndExpire = new uint256[](tmpInt);
            for (uint256 i ; i < length ; i++) {
                tmpInt = i.add(start);
                tmpInt = _listType == 0 ? tmpInt :
                         _listType == 1 ? __list[tmpInt] :
                                         __list[tmpInt];
                Offer storage offer = _list[tmpInt];
                index[i] = tmpInt;
                tmpInt =  i.add(length);
                provider[i] = offer.provider;
                lockedAndAllowAll[i] = offer.locked;
                lockedAndAllowAll[tmpInt] = offer.allowAll;
                receiving[i] = offer.receiving;
                amountAndPrice[i] = offer.amount;
                amountAndPrice[tmpInt] = offer.restrictedPrice;
                startDateAndExpire[i] = offer.startDate;
                startDateAndExpire[tmpInt] = offer.expire;
            }
        } else {
            provider = new address[](0);
            lockedAndAllowAll = new bool[](0);
            receiving = amountAndPrice = startDateAndExpire = new uint256[](0);
        }
    }

    function _collectFee(address provider, uint256 feeIn) internal {
        if (msg.sender == provider) {
            _safeTransferFrom(govToken, provider, address(this), feeIn);
            feeBalance = feeBalance.add(feeIn);
            lastGovBalance = lastGovBalance.add(feeIn);
            if (govToken == token0)
                lastToken0Balance = lastToken0Balance.add(feeIn);
            if (govToken == token1)
                lastToken1Balance = lastToken1Balance.add(feeIn);
        } else {
            uint256 balance = IERC20(govToken).balanceOf(address(this));
            uint256 feeDiff = balance.sub(lastGovBalance);
            require(feeDiff >= feeIn, "Not enough fee");
            feeBalance = feeBalance.add(feeDiff);
            lastGovBalance = balance;
            if (govToken == token0)
                lastToken0Balance = balance;
            if (govToken == token1)
                lastToken1Balance = balance;
        }
    }

    function createOrder(address provider, bool direction, bool allowAll, uint256 restrictedPrice, uint256 startDate, uint256 expire) external override returns (uint256 index) {
        uint256 feeIn = uint256(IOSWAP_ConfigStore(configStore).customParam(FEE_PER_ORDER));
        index = _createOrder(provider, direction, allowAll, restrictedPrice, startDate, expire, feeIn);
    }
    function createOrderWithPrepaidFee(address provider, bool direction, bool allowAll, uint256 restrictedPrice, uint256 startDate, uint256 expire, uint feeIn) external override returns (uint256 index) {
        index = _createOrder(provider, direction, allowAll, restrictedPrice, startDate, expire, feeIn);
        prepaidFeeBalance[direction][index] = feeIn.sub(uint256(IOSWAP_ConfigStore(configStore).customParam(FEE_PER_ORDER)));
    }
    function _createOrder(address provider, bool direction, bool allowAll, uint256 restrictedPrice, uint256 startDate, uint256 expire, uint feeIn) internal lock returns (uint256 index) {
        require(IOSWAP_RestrictedFactory(factory).isLive(), 'GLOBALLY PAUSED');
        require(isLive, "PAUSED");
        require(msg.sender == restrictedLiquidityProvider || msg.sender == provider, "Not from router or owner");
        require(expire >= startDate, "Already expired");
        require(expire >= block.timestamp, "Already expired");
        {
        uint256 maxDur = uint256(IOSWAP_ConfigStore(configStore).customParam(MAX_DUR));
        require(expire <= block.timestamp + maxDur, "Expire too far away");
        }

        index = (++counter[direction]);
        providerOfferIndex[direction][provider].push(index);

        offers[direction].push(Offer({
            provider: provider,
            locked: false,
            allowAll: allowAll,
            amount: 0,
            receiving: 0,
            restrictedPrice: restrictedPrice,
            startDate: startDate,
            expire: expire
        }));

        _collectFee(provider, feeIn);

        emit NewProviderOffer(provider, direction, index, allowAll, restrictedPrice, startDate, expire);
    }
    function addPrepaidFee(address provider, bool direction, uint256 index, uint256 feeIn) external override lock {
        uint256 oldBalance = prepaidFeeBalance[direction][index];
        _collectFee(provider, feeIn);
        prepaidFeeBalance[direction][index] = oldBalance.add(feeIn);
    }

    function addLiquidity(bool direction, uint256 index) external override lock {
        require(IOSWAP_RestrictedFactory(factory).isLive(), 'GLOBALLY PAUSED');
        require(isLive, "PAUSED");
        Offer storage offer = offers[direction][index];
        require(msg.sender == restrictedLiquidityProvider || msg.sender == offer.provider, "Not from router or owner");

        (uint256 newGovBalance, uint256 newToken0Balance, uint256 newToken1Balance) = getBalances();

        uint256 amountIn;
        if (direction) {
            amountIn = newToken1Balance.sub(lastToken1Balance);
        } else {
            amountIn = newToken0Balance.sub(lastToken0Balance);
        }
        require(amountIn > 0, "No amount in");

        offer.amount = offer.amount.add(amountIn);

        lastGovBalance = newGovBalance;
        lastToken0Balance = newToken0Balance;
        lastToken1Balance = newToken1Balance;

        emit AddLiquidity(offer.provider, direction, index, amountIn, offer.amount);
    }
    function lockOffer(bool direction, uint256 index) external override {
        Offer storage offer = offers[direction][index];
        require(msg.sender == restrictedLiquidityProvider || msg.sender == offer.provider, "Not from router or owner");
        offer.locked = true;
        emit Lock(direction, index);
    }

    function removeLiquidity(address provider, bool direction, uint256 index, uint256 amountOut, uint256 receivingOut) external override lock {
        require(msg.sender == restrictedLiquidityProvider || msg.sender == provider, "Not from router or owner");
        _removeLiquidity(provider, direction, index, amountOut, receivingOut);
        (address tokenA, address tokenB) = direction ? (token1,token0) : (token0,token1);
        _safeTransfer(tokenA, msg.sender, amountOut); // optimistically transfer tokens
        _safeTransfer(tokenB, msg.sender, receivingOut); // optimistically transfer tokens
        _sync();
    }
    function removeAllLiquidity(address provider) external override lock returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _removeAllLiquidity1D(provider, false);
        (uint256 amount2, uint256 amount3) = _removeAllLiquidity1D(provider, true);
        amount0 = amount0.add(amount3);
        amount1 = amount1.add(amount2);
    }
    function removeAllLiquidity1D(address provider, bool direction) external override lock returns (uint256 totalAmount, uint256 totalReceiving) {
        return _removeAllLiquidity1D(provider, direction);
    }
    function _removeAllLiquidity1D(address provider, bool direction) internal returns (uint256 totalAmount, uint256 totalReceiving) {
        require(msg.sender == restrictedLiquidityProvider || msg.sender == provider, "Not from router or owner");
        uint256[] storage list = providerOfferIndex[direction][provider];
        uint256 length =  list.length;
        for (uint256 i = 0 ; i < length ; i++) {
            uint256 index = list[i];
            Offer storage offer = offers[direction][index]; 
            totalAmount = totalAmount.add(offer.amount);
            totalReceiving = totalReceiving.add(offer.receiving);
            _removeLiquidity(provider, direction, index, offer.amount, offer.receiving);
        }
        (uint256 amount0, uint256 amount1) = direction ? (totalReceiving, totalAmount) : (totalAmount, totalReceiving);
        _safeTransfer(token0, msg.sender, amount0); // optimistically transfer tokens
        _safeTransfer(token1, msg.sender, amount1); // optimistically transfer tokens
        _sync();
    }
    function _removeLiquidity(address provider, bool direction, uint256 index, uint256 amountOut, uint256 receivingOut) internal {
        require(index > 0, "Provider liquidity not found");

        Offer storage offer = offers[direction][index]; 
        require(offer.provider == provider, "Not from provider");

        if (offer.locked && amountOut > 0) {
            require(offer.expire < block.timestamp, "Not expired");
        }

        offer.amount = offer.amount.sub(amountOut);
        offer.receiving = offer.receiving.sub(receivingOut);

        emit RemoveLiquidity(provider, direction, index, amountOut, receivingOut, offer.amount, offer.receiving);
    }

    function getApprovedTraderLength(bool direction, uint256 offerIndex) external override view returns (uint256) {
        return approvedTrader[direction][offerIndex].length;
    }
    function getApprovedTrader(bool direction, uint256 offerIndex, uint256 start, uint256 length) external view override returns (address[] memory trader, uint256[] memory allocation) {
        address[] storage list = approvedTrader[direction][offerIndex];
        uint256 listLength = list.length;
        if (start < listLength) {
            if (start.add(length) > listLength) {
                length = listLength.sub(start);
            }
            trader = new address[](length);
            allocation = new uint256[](length);
            for (uint256 i = 0 ; i < length ; i++) {
                allocation[i] = traderAllocation[direction][offerIndex][ trader[i] = list[i.add(start)] ];
            }
        } else {
            trader = new address[](0);
            allocation = new uint256[](0);
        }
    }
    function _recoverSigner(bytes32 hash, bytes memory signature) private pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        if (signature.length != 65) {
            return (address(0));
        }
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        if (v < 27) {
            v += 27;
        }
        if (v != 27 && v != 28) {
            return (address(0));
        } else {
            return ecrecover(hash, v, r, s);
        }
    }
    function _checkApprovedTrader(bool direction, uint256 offerIndex, uint256 count) internal {
        Offer storage offer = offers[direction][offerIndex]; 
        require(msg.sender == restrictedLiquidityProvider || msg.sender == offer.provider, "Not from router or owner");
        require(!offer.locked, "Offer locked");
        require(!offer.allowAll, "Offer was set to allow all");
        uint256 fee = uint256(IOSWAP_ConfigStore(configStore).customParam(FEE_PER_TRADER)).mul(count);
        uint256 prePaid = prepaidFeeBalance[direction][offerIndex];
        if (prePaid > 0) {
            if (prePaid > fee) {
                prepaidFeeBalance[direction][offerIndex] = prePaid.sub(fee);
            } else {
                prepaidFeeBalance[direction][offerIndex] = 0;
                _collectFee(offer.provider, fee.sub(prePaid));
            }
        } else {
            _collectFee(offer.provider, fee);
        }
    }
    function setApprovedTrader(bool direction, uint256 offerIndex, address trader, uint256 allocation) external override {
        _checkApprovedTrader(direction, offerIndex, 1);
        _setApprovedTrader(direction, offerIndex, trader, allocation);
    }
    function setApprovedTraderBySignature(bool direction, uint256 offerIndex, address trader, uint256 allocation, bytes calldata signature) external override {
        require(traderAllocation[direction][offerIndex][trader] == 0, "already set");

        address signer = _recoverSigner(keccak256(abi.encodePacked(direction, offerIndex, trader, allocation)), signature);
        require(signer == offers[direction][offerIndex].provider, "invalid signature");

        // collect fee from trader instead of LP
        uint256 fee = uint256(IOSWAP_ConfigStore(configStore).customParam(FEE_PER_TRADER));
        prepaidFeeBalance[direction][offerIndex] = prepaidFeeBalance[direction][offerIndex].sub(fee);

        _setApprovedTrader(direction, offerIndex, trader, allocation);
    }
    function setMultipleApprovedTraders(bool direction, uint256 offerIndex, address[] calldata trader, uint256[] calldata allocation) external override {
        uint256 length = trader.length;
        require(length == allocation.length, "length not match");
        _checkApprovedTrader(direction, offerIndex, length);
        for (uint256 i = 0 ; i < length ; i++) {
            _setApprovedTrader(direction, offerIndex, trader[i], allocation[i]);
        }
    }
    function _setApprovedTrader(bool direction, uint256 offerIndex, address trader, uint256 allocation) internal {
        if (!isApprovedTrader[direction][offerIndex][trader]){
            approvedTrader[direction][offerIndex].push(trader);
            isApprovedTrader[direction][offerIndex][trader] = true;
            traderOffer[direction][trader].push(offerIndex);
        }
        traderAllocation[direction][offerIndex][trader] = allocation;

        emit ApprovedTrader(direction, offerIndex, trader, allocation);
    }

    // format for the data parameter
    // data size + offer index length + list offer index (+ amount for that offer) 
    function swap(uint256 amount0Out, uint256 amount1Out, address to, address trader, bytes calldata /*data*/) external override lock {
        if (!IOSWAP_OracleFactory(whitelistFactory).isWhitelisted(msg.sender)) {
            require(tx.origin == msg.sender && !Address.isContract(msg.sender) && trader == msg.sender, "Invalid trader");
        }
        require(isLive, "PAUSED");
        uint256 amount0In = IERC20(token0).balanceOf(address(this)).sub(lastToken0Balance);
        uint256 amount1In = IERC20(token1).balanceOf(address(this)).sub(lastToken1Balance);

        uint256 amountOut;
        uint256 protocolFeeCollected;
        if (amount0Out == 0 && amount1Out != 0){
            (amountOut, protocolFeeCollected) = _swap(true, amount0In, trader/*, data*/);
            require(amountOut >= amount1Out, "INSUFFICIENT_AMOUNT");
            _safeTransfer(token1, to, amountOut); // optimistically transfer tokens
            protocolFeeBalance0 = protocolFeeBalance0.add(protocolFeeCollected);
        } else if (amount0Out != 0 && amount1Out == 0){
            (amountOut, protocolFeeCollected) = _swap(false, amount1In, trader/*, data*/);
            require(amountOut >= amount0Out, "INSUFFICIENT_AMOUNT");
            _safeTransfer(token0, to, amountOut); // optimistically transfer tokens
            protocolFeeBalance1 = protocolFeeBalance1.add(protocolFeeCollected);
        } else {
            revert("Not supported");
        }

        _sync();
    }

    function _decodeData(uint256 offset) internal pure returns (uint256[] memory list) {
        uint256 dataRead;
        require(msg.data.length >= offset.add(0x60), "Invalid offer list");
        assembly {
            let count := calldataload(add(offset, 0x20))
            let size := mul(count, 0x20)

            if lt(calldatasize(), add(add(offset, 0x40), size)) { // offset + 0x20 (bytes_size_header) + 0x20 (count) + count*0x20 (list_size)
                revert(0, 0)
            }
            let mark := mload(0x40)
            mstore(0x40, add(mark, add(size, 0x20))) // malloc
            mstore(mark, count) // array length
            calldatacopy(add(mark, 0x20), add(offset, 0x40), size) // copy data to list
            list := mark
            mark := add(mark, add(0x20, size))
            dataRead := add(size, 0x20)
        }
        require(offset.add(dataRead).add(0x20) == msg.data.length, "Invalid data length");
        require(list.length > 0, "Invalid offer list");
    }

    function _swap2(bool direction, address trader, uint256 offerIdx, uint256 amountIn, address oracle, uint256[2] memory fee/*uint256 tradeFee, uint256 protocolFee, uint256 feePerOrder, uint256 feePerTrander*/) internal 
        returns (uint256 remainIn, uint256 amountOut, uint256 tradeFeeCollected, uint256 protocolFeeCollected) 
    {
        require(offerIdx <= counter[direction], "Offer not exist");
        Offer storage offer = offers[direction][offerIdx];
        {
        // check approved list
        require(
            offer.allowAll ||
            isApprovedTrader[direction][offerIdx][trader], 
        "Not a approved trader");

        // check offer period
        require(block.timestamp >= offer.startDate, "Offer not begin yet");
        require(block.timestamp <= offer.expire, "Offer expired");
        }

        uint256 price;
        uint256 amountInPlusFee;
        (amountInPlusFee, amountOut, tradeFeeCollected, price) = _oneOutput(amountIn, trader, direction, offerIdx, oracle, fee[0]);

        if (!offer.allowAll) {
            // stack too deep, use remainIn as alloc
            remainIn = traderAllocation[direction][offerIdx][trader];
            traderAllocation[direction][offerIdx][trader] = remainIn.sub(amountOut);
        }

        remainIn = amountIn.sub(amountInPlusFee);

        if (fee[1] != 0) {
            protocolFeeCollected = tradeFeeCollected.mul(fee[1]).div(FEE_BASE);
            amountInPlusFee/*minusProtoFee*/ = amountInPlusFee.sub(protocolFeeCollected);
        }

        offer.amount = offer.amount.sub(amountOut);
        offer.receiving = offer.receiving.add(amountInPlusFee/*minusProtoFee*/);

        emit SwappedOneOffer(offer.provider, direction, offerIdx, price, amountOut, amountInPlusFee/*minusProtoFee*/, offer.amount, offer.receiving);
    }
    function _swap(bool direction, uint256 amountIn, address trader/*, bytes calldata data*/) internal returns (uint256 totalOut, uint256 totalProtocolFeeCollected) {
        (uint256[] memory list) = _decodeData(0xa4);
        uint256 remainIn = amountIn;
        address oracle;
        uint256[2] memory fee;
        (oracle, fee[0], fee[1])  = IOSWAP_RestrictedFactory(factory).checkAndGetOracleSwapParams(token0, token1);

        uint256 totalTradeFeeCollected;
        uint256 amountOut; uint256 tradeFeeCollected; uint256 protocolFeeCollected;
        for (uint256 index = 0 ; index < list.length ; index++) {
            (remainIn, amountOut, tradeFeeCollected, protocolFeeCollected) = _swap2(direction, trader, list[index], remainIn, oracle, fee);
            totalOut = totalOut.add(amountOut);
            totalTradeFeeCollected = totalTradeFeeCollected.add(tradeFeeCollected);
            totalProtocolFeeCollected = totalProtocolFeeCollected.add(protocolFeeCollected);
        }
        require(remainIn == 0, "Amount exceeds available fund");

        emit Swap(trader, direction, amountIn, totalOut, totalTradeFeeCollected, totalProtocolFeeCollected);
    }

    function sync() external override lock {
        _sync();
    }
    function _sync() internal {
        (lastGovBalance, lastToken0Balance, lastToken1Balance) = getBalances();
    }

    function redeemProtocolFee() external override lock {
        address protocolFeeTo = IOSWAP_RestrictedFactory(factory).protocolFeeTo();
        _safeTransfer(govToken, protocolFeeTo, feeBalance); // optimistically transfer tokens
        _safeTransfer(token0, protocolFeeTo, protocolFeeBalance0); // optimistically transfer tokens
        _safeTransfer(token1, protocolFeeTo, protocolFeeBalance1); // optimistically transfer tokens
        feeBalance = 0;
        protocolFeeBalance0 = 0;
        protocolFeeBalance1 = 0;
        
        _sync();
    }
}