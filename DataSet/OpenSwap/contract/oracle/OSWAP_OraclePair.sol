// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../interfaces/IERC20.sol';
import './interfaces/IOSWAP_OraclePair.sol';
import './interfaces/IOSWAP_OracleFactory.sol';
import '../gov/interfaces/IOAXDEX_Governance.sol';
import './interfaces/IOSWAP_OracleAdaptor.sol';
import '../libraries/SafeMath.sol';
import '../libraries/Address.sol';
import '../commons/OSWAP_PausablePair.sol';

contract OSWAP_OraclePair is IOSWAP_OraclePair, OSWAP_PausablePair {
    using SafeMath for uint256;

    uint256 constant FEE_BASE = 10 ** 5;
    uint256 constant FEE_BASE_SQ = (10 ** 5) ** 2;
    uint256 constant WEI = 10**18;

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyEndUser() {
        require((tx.origin == msg.sender && !Address.isContract(msg.sender)) || IOSWAP_OracleFactory(factory).isWhitelisted(msg.sender), "Not from user or whitelisted");
        _;
    }
    modifier onlyDelegator(address provider) {
        require(provider == msg.sender || delegator[provider] == msg.sender, "Not a delegator");
        _;
    }

    uint256 public override counter;
    mapping (bool => uint256) public override first;
    mapping (bool => uint256) public override queueSize;
    mapping (bool => mapping (uint256 => Offer)) public override offers;
    mapping (address => uint256) public override providerOfferIndex;
    mapping (address => address) public override delegator;

    address public override immutable governance;
    address public override immutable oracleLiquidityProvider;
    address public override immutable govToken;
    address public override token0;
    address public override token1;
    bool public override scaleDirection;
    uint256 public override scaler;

    uint256 public override lastGovBalance;
    uint256 public override lastToken0Balance;
    uint256 public override lastToken1Balance;
    uint256 public override protocolFeeBalance0;
    uint256 public override protocolFeeBalance1;
    uint256 public override stakeBalance;
    uint256 public override feeBalance;

    constructor() public {
        address _governance = IOSWAP_OracleFactory(msg.sender).governance();
        governance = _governance;
        govToken = IOAXDEX_Governance(_governance).oaxToken();
        oracleLiquidityProvider = IOSWAP_OracleFactory(msg.sender).oracleLiquidityProvider();
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external override {
        require(msg.sender == factory, 'FORBIDDEN'); // sufficient check

        token0 = _token0;
        token1 = _token1;

        offers[true][0].provider = address(this);
        offers[false][0].provider = address(this);
        require(token0 < token1, "Invalid token pair order");
        address oracle = IOSWAP_OracleFactory(factory).oracles(token0, token1);
        require(oracle != address(0), "No oracle found");

        uint8 token0Decimals = IERC20(token0).decimals();
        uint8 token1Decimals = IERC20(token1).decimals();
        scaleDirection = token1Decimals > token0Decimals;
        scaler = 10 ** uint256(scaleDirection ? (token1Decimals - token0Decimals) : (token0Decimals - token1Decimals));
    }

    function getLastBalances() external override view returns (uint256, uint256) {
        return (
            lastToken0Balance,
            lastToken1Balance
        );
    }
    function getBalances() public override view returns (uint256, uint256, uint256) {
        return (
            IERC20(govToken).balanceOf(address(this)),
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
    }

    function getLatestPrice(bool direction, bytes calldata payload) public override view returns (uint256) {
        (address oracle,,) = IOSWAP_OracleFactory(factory).checkAndGetOracleSwapParams(token0, token1);
        (address tokenA, address tokenB) = direction ? (token0, token1) : (token1, token0);
        return IOSWAP_OracleAdaptor(oracle).getLatestPrice(tokenA, tokenB, payload);
    }

    function _safeTransfer(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FAILED');
    }
    function _safeTransferFrom(address token, address from, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FROM_FAILED');
    }
    function minLotSize(bool direction) internal view returns (uint256) {
        return IOSWAP_OracleFactory(factory).minLotSize(direction ? token1 : token0);
    }

    function _getSwappedAmount(bool direction, uint256 amountIn, bytes calldata data) internal view returns (uint256 amountOut, uint256 price, uint256 tradeFeeCollected, uint256 tradeFee, uint256 protocolFee) {
        address oracle;
        (oracle, tradeFee, protocolFee)  = IOSWAP_OracleFactory(factory).checkAndGetOracleSwapParams(token0, token1);
        tradeFeeCollected = amountIn.mul(tradeFee).div(FEE_BASE);
        amountIn = amountIn.sub(tradeFeeCollected);
        (uint256 numerator, uint256 denominator) = IOSWAP_OracleAdaptor(oracle).getRatio(direction ? token0 : token1, direction ? token1 : token0, amountIn, 0, data);
        amountOut = amountIn.mul(numerator);
        if (scaler > 1)
            amountOut = (direction == scaleDirection) ? amountOut.mul(scaler) : amountOut.div(scaler);
        amountOut = amountOut.div(denominator);
        price = numerator.mul(WEI).div(denominator);
    }
    function getAmountOut(address tokenIn, uint256 amountIn, bytes calldata data) public override view returns (uint256 amountOut) {
        require(amountIn > 0, 'INSUFFICIENT_INPUT_AMOUNT');
        (amountOut,,,,) = _getSwappedAmount(tokenIn == token0, amountIn, data);
    }
    function getAmountIn(address tokenOut, uint256 amountOut, bytes calldata data) public override view returns (uint256 amountIn) {
        require(amountOut > 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        (address oracle, uint256 tradeFee,)  = IOSWAP_OracleFactory(factory).checkAndGetOracleSwapParams(token0, token1);
        bool direction = tokenOut == token1;
        address tokenIn = direction ? token0 : token1;
        (uint256 numerator, uint256 denominator) = IOSWAP_OracleAdaptor(oracle).getRatio(tokenIn, tokenOut, 0, amountOut, data);
        amountIn = amountOut.mul(denominator);
        if (scaler > 1)
            amountIn = (direction != scaleDirection) ? amountIn.mul(scaler) : amountIn.div(scaler);
        amountIn = amountIn.div(numerator).add(1);
        amountIn = amountIn.mul(FEE_BASE).div(FEE_BASE.sub(tradeFee)).add(1);
    }

    function setDelegator(address _delegator, uint256 fee) external override {
        address provider = msg.sender;
        delegator[provider] = _delegator;
        if (_delegator != address(0)) {
            uint256 feePerDelegator = IOSWAP_OracleFactory(factory).feePerDelegator();
            if (feePerDelegator > 0) {
                require(fee == feePerDelegator, "Fee Mismatch");
                feeBalance = feeBalance.add(feePerDelegator);
                _safeTransferFrom(govToken, provider, address(this), feePerDelegator);
            }
        }
        emit SetDelegator(provider, _delegator);
    }

    function getQueue(bool direction, uint256 start, uint256 end) external view override returns (uint256[] memory index, address[] memory provider, uint256[] memory amount, uint256[] memory staked, uint256[] memory expire) {
        uint256 _queueSize = queueSize[direction];
        if (start < _queueSize) {
            if (end >= _queueSize)
                end = _queueSize == 0 ? 0 : _queueSize.sub(1);
            uint256 count = end.add(1).sub(start);
            uint256 i = 0;
            Offer storage offer;
            uint256 currIndex = first[direction];
            for (offer = offers[direction][currIndex] ; i < start ; offer = offers[direction][currIndex = offer.next]) {
                i++;
            }
            return getQueueFromIndex(direction, currIndex, count);
        } else {
            index = amount = staked = expire = new uint256[](0);
            provider = new address[](0);
        }
    }
    function getQueueFromIndex(bool direction, uint256 from, uint256 count) public view override returns (uint256[] memory index, address[] memory provider, uint256[] memory amount, uint256[] memory staked, uint256[] memory expire) {
        index = new uint256[](count);
        provider = new address[](count);
        amount = new uint256[](count);
        staked = new uint256[](count);
        expire = new uint256[](count);

        uint256 i = 0;
        Offer storage offer = offers[direction][from];
        uint256 currIndex = from;
        for (i = 0; i < count && currIndex != 0; i++) {
            index[i] = currIndex;
            provider[i] = offer.provider;
            amount[i] = offer.amount;
            staked[i] = offer.staked;
            expire[i] = offer.expire;
            offer = offers[direction][currIndex = offer.next];
        }
    }
    function getProviderOffer(address provider, bool direction) external view override returns (uint256 index, uint256 staked, uint256 amount, uint256 reserve, uint256 expire, bool privateReplenish) {
        index = providerOfferIndex[provider];
        Offer storage offer = offers[direction][index];
        return (index, offer.staked, offer.amount, offer.reserve, offer.expire, offer.privateReplenish);
    }
    function findPosition(bool direction, uint256 staked, uint256 _afterIndex) public view override returns (uint256 afterIndex, uint256 nextIndex) {
        afterIndex = _afterIndex;
        if (afterIndex == 0){
            nextIndex = first[direction];
        } else {
            Offer storage prev = offers[direction][afterIndex];
            require(prev.provider != address(0), "Invalid index");

            while (prev.staked < staked) {
                afterIndex = prev.prev;
                if (afterIndex == 0){
                    break;
                } 
                prev = offers[direction][afterIndex];
            }
            nextIndex = afterIndex == 0 ? first[direction] : prev.next;
        }

        if (nextIndex > 0) {
            Offer storage next = offers[direction][nextIndex];
            while (staked <= next.staked) {
                afterIndex = nextIndex;
                nextIndex = next.next;
                if (nextIndex == 0) {
                    break;
                }
                next = offers[direction][nextIndex];
            }
        }
    }
    function _enqueue(bool direction, uint256 index, uint256 staked, uint256 afterIndex, uint256 amount, uint256 expire) internal {
        if (amount > 0 && expire > block.timestamp) {
            uint256 nextIndex;
            (afterIndex, nextIndex) = findPosition(direction, staked, afterIndex);

            if (afterIndex != 0)
                offers[direction][afterIndex].next = index;
            if (nextIndex != 0)
                offers[direction][nextIndex].prev = index;

            Offer storage offer = offers[direction][index];
            offer.prev = afterIndex;
            offer.next = nextIndex;

            if (afterIndex == 0){
                first[direction] = index;
            }

            if (!offer.isActive) {
                offer.isActive = true;
                queueSize[direction]++;
            }
        }
    }
    function _halfDequeue(bool direction, uint index) internal returns (uint256 prevIndex, uint256 nextIndex) {
        Offer storage offer = offers[direction][index];
        nextIndex = offer.next;
        prevIndex = offer.prev;

        if (prevIndex != 0) {
            offers[direction][prevIndex].next = nextIndex;
        }

        if (nextIndex != 0) {
            offers[direction][nextIndex].prev = prevIndex;
        }

        if (first[direction] == index){
            first[direction] = nextIndex;
        }
    }

    function _dequeue(bool direction, uint index) internal returns (uint256 nextIndex) {
        (,nextIndex) = _halfDequeue(direction, index);

        Offer storage offer = offers[direction][index];
        offer.prev = 0;
        offer.next = 0;
        offer.isActive = false;
        queueSize[direction] = queueSize[direction].sub(1);
    }

    function _newOffer(address provider, bool direction, uint256 index, uint256 staked, uint256 afterIndex, uint256 amount, uint256 expire, bool enable) internal {
        require(amount >= minLotSize(direction), "Minium lot size not met");

        if (enable)
            _enqueue(direction, index, staked, afterIndex, amount, expire);

        Offer storage offer = offers[direction][index];
        offer.provider = provider;
        offer.staked = staked;
        offer.amount = amount;
        offer.expire = expire;
        offer.privateReplenish = true;
        offer.enabled = enable;

        Offer storage counteroffer = offers[!direction][index];
        counteroffer.provider = provider;
        counteroffer.privateReplenish = true;
        counteroffer.enabled = enable;
    }
    function _renewOffer(bool direction, uint256 index, uint256 stakeAdded, uint256 afterIndex, uint256 amountAdded, uint256 expire, bool enable) internal {
        Offer storage offer = offers[direction][index];
        uint256 newAmount = offer.amount.add(amountAdded);
        require(newAmount >= minLotSize(direction), "Minium lot size not met");
        uint256 staked = offer.staked.add(stakeAdded);
        offer.enabled = enable;
        if (amountAdded > 0)
            offer.amount = newAmount;
        if (stakeAdded > 0)
            offer.staked = staked;
        offer.expire = expire;

        if (enable) {
            if (offer.isActive) {
                if (stakeAdded > 0 && (index != afterIndex || staked > offers[direction][offer.prev].staked)) {
                    _halfDequeue(direction, index);
                    _enqueue(direction, index, staked, afterIndex, newAmount, expire);
                }
            } else {
                _enqueue(direction, index, staked, afterIndex, newAmount, expire);
            }
        } else {
            if (offer.isActive)
                _dequeue(direction, index);
        }
    }
    function addLiquidity(address provider, bool direction, uint256 staked, uint256 afterIndex, uint256 expire, bool enable) external override lock returns (uint256 index) {
        require(IOSWAP_OracleFactory(factory).isLive(), 'GLOBALLY PAUSED');
        require(msg.sender == oracleLiquidityProvider || msg.sender == provider, "Not from router or owner");
        require(isLive, "PAUSED");
        require(provider != address(0), "Null address");
        require(expire > block.timestamp, "Already expired");

        (uint256 newGovBalance, uint256 newToken0Balance, uint256 newToken1Balance) = getBalances();
        require(newGovBalance.sub(lastGovBalance) >= staked, "Invalid feeIn");
        stakeBalance = stakeBalance.add(staked);
        uint256 amountIn;
        if (direction) {
            amountIn = newToken1Balance.sub(lastToken1Balance);
            if (govToken == token1)
                amountIn = amountIn.sub(staked);
        } else {
            amountIn = newToken0Balance.sub(lastToken0Balance);
            if (govToken == token0)
                amountIn = amountIn.sub(staked);
        }

        index = providerOfferIndex[provider];
        if (index > 0) {
            _renewOffer(direction, index, staked, afterIndex, amountIn, expire, enable);
        } else {
            index = (++counter);
            providerOfferIndex[provider] = index;
            require(amountIn > 0, "No amount in");
            _newOffer(provider, direction, index, staked, afterIndex, amountIn, expire, enable);

            emit NewProvider(provider, index);
        }

        lastGovBalance = newGovBalance;
        lastToken0Balance = newToken0Balance;
        lastToken1Balance = newToken1Balance;

        Offer storage offer = offers[direction][index];
        emit AddLiquidity(provider, direction, staked, amountIn, offer.staked, offer.amount, expire, enable);
    }
    function setPrivateReplenish(bool _replenish) external override lock {
        address provider = msg.sender;
        uint256 index = providerOfferIndex[provider];
        require(index > 0, "Provider not found");
        offers[false][index].privateReplenish = _replenish;
        offers[true][index].privateReplenish = _replenish;
    }
    function replenish(address provider, bool direction, uint256 afterIndex, uint amountIn, uint256 expire) external override lock {
        uint256 index = providerOfferIndex[provider];
        require(index > 0, "Provider not found");

        // move funds from internal wallet
        Offer storage offer = offers[direction][index];
        require(!offer.privateReplenish || provider == msg.sender, "Not from provider");

        if (provider != msg.sender) {
            if (offer.expire == 0) {
                // if expire is not set, set it the same as the counter offer
                expire = offers[!direction][index].expire;
            } else {
                // don't allow others to modify the expire
                expire = offer.expire;
            }
        }
        require(expire > block.timestamp, "Already expired");

        offer.reserve = offer.reserve.sub(amountIn);
        _renewOffer(direction, index, 0, afterIndex, amountIn, expire, offer.enabled);

        emit Replenish(provider, direction, amountIn, offer.amount, offer.reserve, expire);
    }
    function pauseOffer(address provider, bool direction) external override onlyDelegator(provider) {
        uint256 index = providerOfferIndex[provider];
        Offer storage offer = offers[direction][index];
        if (offer.isActive) {
            _dequeue(direction, index);
        }
        offer.enabled = false;
        emit DelegatorPauseOffer(msg.sender, provider, direction);
    }
    function resumeOffer(address provider, bool direction, uint256 afterIndex) external override onlyDelegator(provider) {
        uint256 index = providerOfferIndex[provider];
        Offer storage offer = offers[direction][index];
        
        if (!offer.isActive && offer.expire > block.timestamp && offer.amount >= minLotSize(direction)) {
            _enqueue(direction, index, offer.staked, afterIndex, offer.amount, offer.expire);
        }
        offer.enabled = true;
        emit DelegatorResumeOffer(msg.sender, provider, direction);
    }
    function removeLiquidity(address provider, bool direction, uint256 unstake, uint256 afterIndex, uint256 amountOut, uint256 reserveOut, uint256 expire, bool enable) external override lock {
        require(msg.sender == oracleLiquidityProvider || msg.sender == provider, "Not from router or owner");
        require(expire > block.timestamp, "Already expired");

        uint256 index = providerOfferIndex[provider];
        require(index > 0, "Provider liquidity not found");

        Offer storage offer = offers[direction][index];
        uint256 newAmount = offer.amount.sub(amountOut);
        require(newAmount == 0 || newAmount >= minLotSize(direction), "Minium lot size not met");

        uint256 staked = offer.staked.sub(unstake);
        offer.enabled = enable;
        if (amountOut > 0)
            offer.amount = newAmount;
        if (unstake > 0)
            offer.staked = staked;
        offer.reserve = offer.reserve.sub(reserveOut);
        offer.expire = expire;

        if (enable) {
            if (offer.isActive) {
                if (unstake > 0 && (index != afterIndex || offers[direction][offer.next].staked >= staked)) {
                    _halfDequeue(direction, index);
                    _enqueue(direction, index, staked, afterIndex, newAmount, expire);
                }
            } else {
                _enqueue(direction, index, staked, afterIndex, newAmount, expire);
            }
        } else {
            if (offer.isActive)
                _dequeue(direction, index);
        }

        if (unstake > 0) {
            stakeBalance = stakeBalance.sub(unstake);
            _safeTransfer(govToken, msg.sender, unstake); // optimistically transfer tokens
        }

        if (amountOut > 0 || reserveOut > 0)
            _safeTransfer(direction ? token1 : token0, msg.sender, amountOut.add(reserveOut)); // optimistically transfer tokens
        emit RemoveLiquidity(provider, direction, unstake, amountOut, reserveOut, offer.staked, offer.amount, offer.reserve, expire, enable);

        _sync();
    }
    function removeAllLiquidity(address provider) external override lock returns (uint256 amount0, uint256 amount1, uint256 staked) {
        require(msg.sender == oracleLiquidityProvider || msg.sender == provider, "Not from router or owner");
        uint256 staked0;
        uint256 staked1;
        uint256 reserve0;
        uint256 reserve1;
        (staked1, amount1, reserve1) = _removeAllLiquidityOneSide(provider, true);
        (staked0, amount0, reserve0) = _removeAllLiquidityOneSide(provider, false);
        staked = staked0.add(staked1);
        amount0 = amount0.add(reserve0);
        amount1 = amount1.add(reserve1);
        stakeBalance = stakeBalance.sub(staked);
        _safeTransfer(govToken, msg.sender, staked); // optimistically transfer tokens

        _sync();
    }
    function _removeAllLiquidityOneSide(address provider, bool direction) internal returns (uint256 staked, uint256 amount, uint256 reserve) {
        uint256 index = providerOfferIndex[provider];
        require(index > 0, "Provider liquidity not found");

        Offer storage offer = offers[direction][index];
        require(provider == offer.provider, "Forbidden");
        staked = offer.staked;
        amount = offer.amount;
        reserve = offer.reserve;

        offer.staked = 0;
        offer.amount = 0;
        offer.reserve = 0;

        if (offer.isActive)
            _dequeue(direction, index);
        _safeTransfer(direction ? token1 : token0, msg.sender, amount.add(reserve)); // optimistically transfer tokens
        emit RemoveLiquidity(provider, direction, staked, amount, reserve, 0, 0, 0, 0, offer.enabled);
    }
    function purgeExpire(bool direction, uint256 startingIndex, uint256 limit) external override lock returns (uint256 purge) {
        uint256 index = startingIndex;
        while (index != 0 && limit > 0) {
            Offer storage offer = offers[direction][index];
            if (offer.expire < block.timestamp) {
                index = _dequeue(direction, index);
                purge++;
            } else {
                index = offer.next;
            }
            limit--;
        }
    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external override lock onlyEndUser {
        require(isLive, "PAUSED");
        uint256 amount0In;
        uint256 amount1In;
        amount0In = IERC20(token0).balanceOf(address(this)).sub(lastToken0Balance);
        amount1In = IERC20(token1).balanceOf(address(this)).sub(lastToken1Balance);
        uint256 protocolFeeCollected;

        if (amount0Out == 0 && amount1Out != 0){
            (amount1Out, protocolFeeCollected) = _swap(to, true, amount0In, amount1Out, data);
            _safeTransfer(token1, to, amount1Out); // optimistically transfer tokens
            protocolFeeBalance0 = protocolFeeBalance0.add(protocolFeeCollected);
        } else if (amount0Out != 0 && amount1Out == 0){
            (amount0Out, protocolFeeCollected) = _swap(to, false, amount1In, amount0Out, data);
            _safeTransfer(token0, to, amount0Out); // optimistically transfer tokens
            protocolFeeBalance1 = protocolFeeBalance1.add(protocolFeeCollected);
        } else {
            revert("Not supported");
        }

        _sync();
    }
    function _swap(address to, bool direction, uint256 amountIn, uint256 _amountOut, bytes calldata data) internal returns (uint256 amountOut, uint256 protocolFeeCollected) {
        uint256 amountInMinusProtocolFee;
        {
            uint256 price;
            uint256 tradeFeeCollected;
            uint256 tradeFee;
            uint256 protocolFee;
            (amountOut, price, tradeFeeCollected, tradeFee, protocolFee) = _getSwappedAmount(direction, amountIn, data);
            require(amountOut >= _amountOut, "INSUFFICIENT_AMOUNT");
            if (protocolFee == 0) {
                amountInMinusProtocolFee = amountIn;
            } else {
                protocolFeeCollected = amountIn.mul(tradeFee.mul(protocolFee)).div(FEE_BASE_SQ);
                amountInMinusProtocolFee = amountIn.sub(protocolFeeCollected);
            }
            emit Swap(to, direction, price, amountIn, amountOut, tradeFeeCollected, protocolFeeCollected);
        }

        uint256 remainOut = amountOut;

        uint256 index = first[direction];
        Offer storage offer;
        Offer storage counteroffer;
        while (remainOut > 0 && index != 0) {
            offer = offers[direction][index];
            if (offer.expire < block.timestamp) {
                index = _dequeue(direction, index);
            } else {
                counteroffer = offers[!direction][index];
                uint256 amount = offer.amount;
                if (remainOut >= amount) {
                    // amount requested cover whole entry, clear entry
                    remainOut = remainOut.sub(amount);

                    uint256 providerShare = amountInMinusProtocolFee.mul(amount).div(amountOut);
                    counteroffer.reserve = counteroffer.reserve.add(providerShare);

                    offer.amount = 0;
                    emit SwappedOneProvider(offer.provider, direction, amount, providerShare, 0, counteroffer.reserve);

                    // remove from provider queue
                    index = _dequeue(direction, index);
                } else {
                    // remaining request amount
                    uint256 providerShare = amountInMinusProtocolFee.mul(remainOut).div(amountOut);
                    counteroffer.reserve = counteroffer.reserve.add(providerShare);

                    offer.amount = offer.amount.sub(remainOut);
                    emit SwappedOneProvider(offer.provider, direction, remainOut, providerShare, offer.amount, counteroffer.reserve);

                    remainOut = 0;
                }
            }
        }

        require(remainOut == 0, "Amount exceeds available fund");
    }

    function sync() external override lock {
        _sync();
    }
    function _sync() internal {
        (lastGovBalance, lastToken0Balance, lastToken1Balance) = getBalances();
    }

    function redeemProtocolFee() external override lock {
        address protocolFeeTo = IOSWAP_OracleFactory(factory).protocolFeeTo();
        uint256 _protocolFeeBalance0 = protocolFeeBalance0;
        uint256 _protocolFeeBalance1 = protocolFeeBalance1;
        uint256 _feeBalance = feeBalance;
        _safeTransfer(token0, protocolFeeTo, _protocolFeeBalance0); // optimistically transfer tokens
        _safeTransfer(token1, protocolFeeTo, _protocolFeeBalance1); // optimistically transfer tokens
        _safeTransfer(govToken, protocolFeeTo, _feeBalance); // optimistically transfer tokens
        protocolFeeBalance0 = 0;
        protocolFeeBalance1 = 0;
        feeBalance = 0;
        _sync();
    }
}