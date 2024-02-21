// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './interfaces/IOSWAP_RestrictedPair.sol';
import '../interfaces/IERC20.sol';
import '../libraries/SafeMath.sol';
import '../libraries/Address.sol';
import './interfaces/IOSWAP_RestrictedFactory.sol';
import '../oracle/interfaces/IOSWAP_OracleFactory.sol';
import '../gov/interfaces/IOAXDEX_Governance.sol';
import './interfaces/IOSWAP_ConfigStore.sol';
import '../oracle/interfaces/IOSWAP_OracleAdaptor2.sol';
import '../commons/OSWAP_PausablePair.sol';

contract OSWAP_RestrictedPair is IOSWAP_RestrictedPair, OSWAP_PausablePair {
    using SafeMath for uint256;

    uint256 constant FEE_BASE = 10 ** 5;
    uint256 constant WEI = 10**18;

    bytes32 constant FEE_PER_ORDER = "RestrictedPair.feePerOrder";
    bytes32 constant FEE_PER_TRADER = "RestrictedPair.feePerTrader";
    bytes32 constant MAX_DUR = "RestrictedPair.maxDur";
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    uint256 internal unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    mapping(bool => uint256) public override counter;
    mapping(bool => Offer[]) public override offers;
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

    function _getSwappedAmount(bool direction, uint256 amountIn, address trader, uint256 index, address oracle, uint256 tradeFee) internal view returns (uint256 amountOut, uint256 price, uint256 tradeFeeCollected) {
        tradeFeeCollected = amountIn.mul(tradeFee).div(FEE_BASE);
        amountIn = amountIn.sub(tradeFeeCollected);
        (uint256 numerator, uint256 denominator) = IOSWAP_OracleAdaptor2(oracle).getRatio(direction ? token0 : token1, direction ? token1 : token0, amountIn, 0, trader, abi.encodePacked(index));
        amountOut = amountIn.mul(numerator);
        if (scaler > 1)
            amountOut = (direction == scaleDirection) ? amountOut.mul(scaler) : amountOut.div(scaler);
        amountOut = amountOut.div(denominator);
        price = numerator.mul(WEI).div(denominator);
    }
    function getAmountOut(address tokenIn, uint256 amountIn, address trader, bytes calldata /*data*/) external view override returns (uint256 amountOut) {
        require(amountIn > 0, 'INSUFFICIENT_INPUT_AMOUNT');
        (uint256[] memory list, uint256[] memory amount) = _decodeData(0x84);
        bool direction = token0 == tokenIn;
        (address oracle, uint256 tradeFee, )  = IOSWAP_RestrictedFactory(factory).checkAndGetOracleSwapParams(token0, token1);
        uint256 _amount;
        for (uint256 i = 0 ; i < list.length ; i++) {
            uint256 offerIdx = list[i];
            require(offerIdx <= counter[direction], "Offer not exist");
            _amount = amount[i].mul(amountIn).div(1e18);
            (_amount,,) = _getSwappedAmount(direction, _amount, trader, offerIdx, oracle, tradeFee);
            amountOut = amountOut.add(_amount);
        }
    }
    function getAmountIn(address /*tokenOut*/, uint256 /*amountOut*/, address /*trader*/, bytes calldata /*data*/) external view override returns (uint256 /*amountIn*/) {
        revert("Not supported");
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

    function createOrder(address provider, bool direction, bool allowAll, uint256 restrictedPrice, uint256 startDate, uint256 expire) external override lock returns (uint256 index) {
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

        uint256 feeIn = uint256(IOSWAP_ConfigStore(configStore).customParam(FEE_PER_ORDER));
        _collectFee(provider, feeIn);

        emit NewProviderOffer(provider, direction, index, allowAll, restrictedPrice, startDate, expire);
    }
    function lockOffer(bool direction, uint256 index) external override {
        Offer storage offer = offers[direction][index];
        require(msg.sender == restrictedLiquidityProvider || msg.sender == offer.provider, "Not from router or owner");
        offer.locked = true;
        emit Lock(direction, index);
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

    function _decodeData(uint256 offset) internal pure returns (uint256[] memory list, uint256[] memory amount) {
        uint256 dataRead;
        require(msg.data.length >= offset.add(0x60), "Invalid offer list");
        assembly {
            let count := calldataload(add(offset, 0x20))
            let size := mul(count, 0x20)

            if lt(calldatasize(), add(add(offset, 0x40), mul(2, size))) {//add(offset, add(mul(2, size), 0x20))) { // offset + 0x20 (bytes_size_header) + 0x20 (count) + 2* count*0x20 (list_size)
                revert(0, 0)
            }
            let mark := mload(0x40)
            mstore(0x40, add(mark, mul(2, add(size, 0x20)))) // malloc
            mstore(mark, count) // array length
            calldatacopy(add(mark, 0x20), add(offset, 0x40), size) // copy data to list
            list := mark
            mark := add(mark, add(0x20, size))
            // offset := add(offset, size)
            mstore(mark, count) // array length
            calldatacopy(add(mark, 0x20), add(add(offset, 0x40), size), size) // copy data to list
            amount := mark
            dataRead := add(mul(2, size), 0x20)
        }
        require(offset.add(dataRead).add(0x20) == msg.data.length, "Invalid data length");
        require(list.length > 0, "Invalid offer list");
    }

    function _swap2(bool direction, address trader, uint256 offerIdx, uint256 amountIn, address oracle, uint256[2] memory fee/*uint256 tradeFee, uint256 protocolFee*/) internal 
        returns (uint256 amountOut, uint256 tradeFeeCollected, uint256 protocolFeeCollected) 
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
        uint256 amountInWithholdProtocolFee;
        (amountOut, price, tradeFeeCollected) = _getSwappedAmount(direction, amountIn, trader, offerIdx, oracle, fee[0]);

        if (fee[1] == 0) {
            amountInWithholdProtocolFee = amountIn;
        } else {
            protocolFeeCollected = tradeFeeCollected.mul(fee[1]).div(FEE_BASE);
            amountInWithholdProtocolFee = amountIn.sub(protocolFeeCollected);
        }

        // check allocation
        if (!offer.allowAll) {
            uint256 alloc = traderAllocation[direction][offerIdx][trader];
            require(amountOut <= alloc, "Amount exceeded allocation");
            traderAllocation[direction][offerIdx][trader] = alloc.sub(amountOut);
        }

        require(amountOut <= offer.amount, "Amount exceeds available fund");

        offer.amount = offer.amount.sub(amountOut);
        offer.receiving = offer.receiving.add(amountInWithholdProtocolFee);

        emit SwappedOneOffer(offer.provider, direction, offerIdx, price, amountOut, amountInWithholdProtocolFee, offer.amount, offer.receiving);
    }
    function _swap(bool direction, uint256 amountIn, address trader/*, bytes calldata data*/) internal returns (uint256 totalOut, uint256 totalProtocolFeeCollected) {
        (uint256[] memory idxList, uint256[] memory amountList) = _decodeData(0xa4);
        address oracle;
        uint256[2] memory fee;
        (oracle, fee[0], fee[1])  = IOSWAP_RestrictedFactory(factory).checkAndGetOracleSwapParams(token0, token1);

        uint256 totalIn;
        uint256 totalTradeFeeCollected;
        for (uint256 index = 0 ; index < idxList.length ; index++) {
            totalIn = totalIn.add(amountList[index]);
            uint256[3] memory amount;
            uint256 thisIn = amountList[index].mul(amountIn).div(1e18);
            (amount[0], amount[1], amount[2])/*(uint256 amountOut, uint256 tradeFeeCollected, uint256 protocolFeeCollected)*/ = _swap2(direction, trader, idxList[index], thisIn, oracle, fee/*tradeFee, protocolFee*/);
            totalOut = totalOut.add(amount[0]);
            totalTradeFeeCollected = totalTradeFeeCollected.add(amount[1]);
            totalProtocolFeeCollected = totalProtocolFeeCollected.add(amount[2]);
        }
        require(totalIn == 1e18, "Invalid input");
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