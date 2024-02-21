// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import './interfaces/IOSWAP_RangePair.sol';
import '../interfaces/IERC20.sol';
import '../libraries/SafeMath.sol';
import '../libraries/Address.sol';
import './interfaces/IOSWAP_RangeFactory.sol';
import '../oracle/interfaces/IOSWAP_OracleFactory.sol';
import '../gov/interfaces/IOAXDEX_Governance.sol';
import '../oracle/interfaces/IOSWAP_OracleAdaptor.sol';
import '../commons/OSWAP_PausablePair.sol';

contract OSWAP_RangePair is IOSWAP_RangePair, OSWAP_PausablePair {
    using SafeMath for uint256;

    uint256 constant FEE_BASE = 10 ** 5;
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
        require((tx.origin == msg.sender && !Address.isContract(msg.sender)) || IOSWAP_OracleFactory(oracleFactory).isWhitelisted(msg.sender), "Not from user or whitelisted");
        _;
    }

    uint256 public override counter;
    mapping (bool => Offer[]) public override offers;
    mapping (address => uint256) public override providerOfferIndex;
    mapping (address => uint256) public override providerStaking;

    address public override immutable oracleFactory;
    address public override immutable governance;
    address public override immutable rangeLiquidityProvider;
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

    constructor() public {
        (address _governance, address _rangeLiquidityProvider, address _oracleFactory) = IOSWAP_RangeFactory(msg.sender).getCreateAddresses();
        governance = _governance;
        govToken = IOAXDEX_Governance(_governance).oaxToken();
        rangeLiquidityProvider = _rangeLiquidityProvider;
        oracleFactory = _oracleFactory;

        offers[true].push(Offer({
            provider: address(this),
            amount: 0,
            reserve: 0,
            lowerLimit: 0,
            upperLimit: 0,
            startDate: 0,
            expire: 0,
            privateReplenish: false
        }));
        offers[false].push(Offer({
            provider: address(this),
            amount: 0,
            reserve: 0,
            lowerLimit: 0,
            upperLimit: 0,
            startDate: 0,
            expire: 0,
            privateReplenish: false
        }));
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external override {
        require(msg.sender == factory, 'FORBIDDEN'); // sufficient check

        token0 = _token0;
        token1 = _token1;
        require(token0 < token1, "Invalid token pair order");

        address oracle = IOSWAP_OracleFactory(oracleFactory).oracles(token0, token1);
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

    function getOffers(bool direction, uint256 start, uint256 end) external override view returns (address[] memory provider, uint256[] memory amountAndReserve, uint256[] memory lowerLimitAndUpperLimit, uint256[] memory startDateAndExpire, bool[] memory privateReplenish) {
        if (start <= counter) {
            if (end > counter) 
                end = counter;
            uint256 length = end.add(1).sub(start);
            provider = new address[](length);
            amountAndReserve = new uint256[](length * 2);
            lowerLimitAndUpperLimit = new uint256[](length * 2);
            startDateAndExpire = new uint256[](length * 2);
            privateReplenish = new bool[](length);

            for (uint256 i = 0; i < length ; i++) {
                uint256 j = i.add(length);
                Offer storage offer = offers[direction][i.add(start)];
                provider[i] = offer.provider;
                amountAndReserve[i] = offer.amount;
                amountAndReserve[j] = offer.reserve;
                lowerLimitAndUpperLimit[i] = offer.lowerLimit;
                lowerLimitAndUpperLimit[j] = offer.upperLimit;
                startDateAndExpire[i] = offer.startDate;
                startDateAndExpire[j] = offer.expire;
                privateReplenish[i] = offer.privateReplenish;
            }
        } else {
            provider = new address[](0);
            amountAndReserve = lowerLimitAndUpperLimit = startDateAndExpire = new uint256[](0);
            privateReplenish  = new bool[](0);
        }
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

    function getLatestPrice(bool direction, bytes calldata payload) public view override returns (uint256) {
        address oracle = IOSWAP_OracleFactory(oracleFactory).checkAndGetOracle(token0, token1);
        (address tokenA, address tokenB) = direction ? (token0, token1) : (token1, token0);
        return IOSWAP_OracleAdaptor(oracle).getLatestPrice(tokenA, tokenB, payload);
    }
    function _getSwappedAmount(bool direction, uint256 amountIn, bytes calldata data) internal view returns (uint256 amountOut, uint256 price, uint256 tradeFeeCollected, uint256 tradeFee) {
        address oracle = IOSWAP_OracleFactory(oracleFactory).checkAndGetOracle(token0, token1);
        tradeFee = IOSWAP_RangeFactory(factory).checkAndGetSwapParams();
        tradeFeeCollected = amountIn.mul(tradeFee).div(FEE_BASE);
        amountIn = amountIn.sub(tradeFeeCollected);
        (uint256 numerator, uint256 denominator) = IOSWAP_OracleAdaptor(oracle).getRatio(direction ? token0 : token1, direction ? token1 : token0, amountIn, 0, data);
        amountOut = amountIn.mul(numerator);
        if (scaler > 1)
            amountOut = (direction == scaleDirection) ? amountOut.mul(scaler) : amountOut.div(scaler);
        amountOut = amountOut.div(denominator);
        price = numerator.mul(WEI).div(denominator);
    }
    function getAmountOut(address tokenIn, uint256 amountIn, bytes calldata data) external view override returns (uint256 amountOut) {
        require(amountIn > 0, 'INSUFFICIENT_INPUT_AMOUNT');
        (amountOut,,,) = _getSwappedAmount(tokenIn == token0, amountIn, data);
    }
    function getAmountIn(address tokenOut, uint256 amountOut, bytes calldata data) external view override returns (uint256 amountIn) {
        require(amountOut > 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        address oracle = IOSWAP_OracleFactory(oracleFactory).checkAndGetOracle(token0, token1);
        uint256 tradeFee = IOSWAP_RangeFactory(factory).checkAndGetSwapParams();
        bool direction = tokenOut == token1;
        address tokenIn = direction ? token0 : token1;
        (uint256 numerator, uint256 denominator) = IOSWAP_OracleAdaptor(oracle).getRatio(tokenIn, tokenOut, 0, amountOut, data);
        amountIn = amountOut.mul(denominator);
        if (scaler > 1)
            amountIn = (direction != scaleDirection) ? amountIn.mul(scaler) : amountIn.div(scaler);
        amountIn = amountIn.div(numerator).add(1);
        amountIn = amountIn.mul(FEE_BASE).div(FEE_BASE.sub(tradeFee)).add(1);
    }

    function getProviderOffer(address provider, bool direction) external view override returns (uint256 index, uint256 staked, uint256 amount, uint256 reserve, uint256 lowerLimit, uint256 upperLimit, uint256 startDate, uint256 expire, bool privateReplenish) {
        index = providerOfferIndex[provider];
        Offer storage offer = offers[direction][index];
        return (index, providerStaking[provider], offer.amount, offer.reserve, offer.lowerLimit, offer.upperLimit, offer.startDate, offer.expire, offer.privateReplenish);
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FAILED');
    }

    function addLiquidity(address provider, bool direction, uint256 staked, uint256 lowerLimit, uint256 upperLimit, uint256 startDate, uint256 expire) external override lock returns (uint256 index) {
        require(IOSWAP_RangeFactory(factory).isLive(), 'GLOBALLY PAUSED');
        require(msg.sender == rangeLiquidityProvider || msg.sender == provider, "Not from router or owner");
        require(isLive, "PAUSED");
        require(provider != address(0), "Null address");
        require(lowerLimit <= upperLimit, "Invalid limit");
        require(expire >= startDate, "Already expired");
        require(expire >= block.timestamp, "Already expired");
        uint256 amountIn;
        {
        (uint256 newGovBalance, uint256 newToken0Balance, uint256 newToken1Balance) = getBalances();
        require(newGovBalance.sub(lastGovBalance) >= staked, "Invalid feeIn");
        stakeBalance = stakeBalance.add(staked);
        if (direction) {
            amountIn = newToken1Balance.sub(lastToken1Balance);
            if (govToken == token1)
                amountIn = amountIn.sub(staked);
        } else {
            amountIn = newToken0Balance.sub(lastToken0Balance);
            if (govToken == token0)
                amountIn = amountIn.sub(staked);
        }

        lastGovBalance = newGovBalance;
        lastToken0Balance = newToken0Balance;
        lastToken1Balance = newToken1Balance;
        }

        providerStaking[provider] = providerStaking[provider].add(staked);
        uint256 newStakeBalance; uint256 newAmountBalance;
        newStakeBalance = providerStaking[provider];
        index = providerOfferIndex[provider];
        if (index > 0) {
            Offer storage offer = offers[direction][index];
            newAmountBalance = offer.amount = offer.amount.add(amountIn);
            offer.lowerLimit = lowerLimit;
            offer.upperLimit = upperLimit;
            offer.startDate = startDate;
            offer.expire = expire;
        } else {
            index = (++counter);
            providerOfferIndex[provider] = index;
            require(amountIn > 0, "No amount in");

            offers[direction].push(Offer({
                provider: provider,
                amount: amountIn,
                reserve: 0,
                lowerLimit: lowerLimit,
                upperLimit: upperLimit,
                startDate: startDate,
                expire: expire,
                privateReplenish: true
            }));
            offers[!direction].push(Offer({
                provider: provider,
                amount: 0,
                reserve: 0,
                lowerLimit: 0,
                upperLimit: 0,
                startDate: 0,
                expire: 0,
                privateReplenish: true
            }));

            newAmountBalance = amountIn;

            emit NewProvider(provider, index);
        }

        emit AddLiquidity(provider, direction, staked, amountIn, newStakeBalance, newAmountBalance, lowerLimit, upperLimit, startDate, expire);
    }
    function replenish(address provider, bool direction, uint256 amountIn) external override lock {
        uint256 index = providerOfferIndex[provider];
        require(index > 0, "Provider not found");

        // move funds from internal wallet
        Offer storage offer = offers[direction][index];
        require(!offer.privateReplenish || provider == msg.sender, "Not from provider");

        offer.amount = offer.amount.add(amountIn);
        offer.reserve = offer.reserve.sub(amountIn);

        emit Replenish(provider, direction, amountIn, offer.amount, offer.reserve);
    }
    function updateProviderOffer(address provider, bool direction, uint256 replenishAmount, uint256 lowerLimit, uint256 upperLimit, uint256 startDate, uint256 expire, bool privateReplenish) external override {
        require(msg.sender == rangeLiquidityProvider || msg.sender == provider, "Not from router or owner");
        require(IOSWAP_RangeFactory(factory).isLive(), 'GLOBALLY PAUSED');
        require(isLive, "PAUSED");
        require(lowerLimit <= upperLimit, "Invalid limit");
        require(expire >= startDate, "Already expired");
        require(expire > block.timestamp, "Already expired");
        uint256 index = providerOfferIndex[provider];
        require(index > 0, "Provider liquidity not found");

        Offer storage offer = offers[direction][index];
        offer.amount = offer.amount.add(replenishAmount);
        offer.reserve = offer.reserve.sub(replenishAmount);
        offer.lowerLimit = lowerLimit;
        offer.upperLimit = upperLimit;
        offer.startDate = startDate;
        offer.expire = expire;
        offer.privateReplenish = privateReplenish;

        emit UpdateProviderOffer(msg.sender, direction, replenishAmount, offer.amount, offer.reserve, lowerLimit, upperLimit, startDate, expire, privateReplenish);
    }
    function removeLiquidity(address provider, bool direction, uint256 unstake, uint256 amountOut, uint256 reserveOut, uint256 lowerLimit, uint256 upperLimit, uint256 startDate, uint256 expire) external override lock {
        require(msg.sender == rangeLiquidityProvider || msg.sender == provider, "Not from router or owner");
        require(expire >= startDate, "Already expired");
        require(expire > block.timestamp, "Already expired");

        uint256 index = providerOfferIndex[provider];
        require(index > 0, "Provider liquidity not found");

        if (unstake > 0) {
            providerStaking[provider] = providerStaking[provider].sub(unstake);
            stakeBalance = stakeBalance.sub(unstake);
            _safeTransfer(govToken, msg.sender, unstake); // optimistically transfer tokens
        }
        uint256 newStakeBalance = providerStaking[provider];

        Offer storage offer = offers[direction][index]; 
        offer.amount = offer.amount.sub(amountOut);
        offer.reserve = offer.reserve.sub(reserveOut);
        offer.lowerLimit = lowerLimit;
        offer.upperLimit = upperLimit;
        offer.startDate = startDate;
        offer.expire = expire;

        if (amountOut > 0 || reserveOut > 0)
            _safeTransfer(direction ? token1 : token0, msg.sender, amountOut.add(reserveOut)); // optimistically transfer tokens

        emit RemoveLiquidity(provider, direction, unstake, amountOut, reserveOut, newStakeBalance, offer.amount, offer.reserve, lowerLimit, upperLimit, startDate, expire);

        _sync();
    }
    function removeAllLiquidity(address provider) external override lock returns (uint256 amount0, uint256 amount1, uint256 staked) {
        require(msg.sender == rangeLiquidityProvider || msg.sender == provider, "Not from router or owner");

        uint256 reserve0;
        (amount0, reserve0) = _removeAllLiquidityOneSide(provider, false);
        amount0 = amount0.add(reserve0);

        uint256 reserve1;
        (amount1, reserve1) = _removeAllLiquidityOneSide(provider, true);
        amount1 = amount1.add(reserve1);

        staked = providerStaking[provider];
        providerStaking[provider] = 0;
        if (staked > 0) {
            stakeBalance = stakeBalance.sub(staked);
            _safeTransfer(govToken, msg.sender, staked);
        }

        emit RemoveAllLiquidity(provider, staked, amount0, amount1);

        _sync();
    }
    function _removeAllLiquidityOneSide(address provider, bool direction) internal returns (uint256 amount, uint256 reserve) {
        uint256 index = providerOfferIndex[provider];
        require(index > 0, "Provider liquidity not found");

        Offer storage offer = offers[direction][index];
        amount = offer.amount;
        reserve = offer.reserve;
        offer.amount = 0;
        offer.reserve = 0;

        _safeTransfer(direction ? token1 : token0, msg.sender, amount.add(reserve));
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external override lock onlyEndUser {
        require(isLive, "PAUSED");
        uint256 amount0In = IERC20(token0).balanceOf(address(this)).sub(lastToken0Balance);
        uint256 amount1In = IERC20(token1).balanceOf(address(this)).sub(lastToken1Balance);

        uint256 amountOut;
        uint256 protocolFeeCollected;
        if (amount0Out == 0 && amount1Out != 0){
            (amountOut, protocolFeeCollected) = _swap(to, true, amount0In, data);
            require(amountOut >= amount1Out, "INSUFFICIENT_AMOUNT");
            _safeTransfer(token1, to, amountOut); // optimistically transfer tokens
            protocolFeeBalance0 = protocolFeeBalance0.add(protocolFeeCollected);
        } else if (amount0Out != 0 && amount1Out == 0){
            (amountOut, protocolFeeCollected) = _swap(to, false, amount1In, data);
            require(amountOut >= amount0Out, "INSUFFICIENT_AMOUNT");
            _safeTransfer(token0, to, amountOut); // optimistically transfer tokens
            protocolFeeBalance1 = protocolFeeBalance1.add(protocolFeeCollected);
        } else {
            revert("Not supported");
        }

        _sync();
    }
    function _swap(address to, bool direction, uint256 amountIn, bytes calldata data) internal returns (uint256 amountOut, uint256 protocolFeeCollected) {
        uint256 price;
        uint256 amountInMinusProtocolFee;
        uint256 tradeFeeCollected;
        uint256[] memory list;
        {
        uint256 dataRead;
        (list, dataRead) = _getOfferList(0x84);
        (amountOut, price, tradeFeeCollected, /*tradeFee*/) = _getSwappedAmount(direction, amountIn, data[dataRead:]);
        }
        protocolFeeCollected = tradeFeeCollected;
        amountInMinusProtocolFee = amountIn.sub(tradeFeeCollected);

        uint256 remainOut = amountOut;
        {
        bool _direction = direction;
        uint256 index = 0;
        while (remainOut > 0 && index < list.length) {
            require(list[index] <= counter, "Offer not exist");
            Offer storage offer = offers[_direction][list[index]];
            if (((offer.lowerLimit <= price && price <= offer.upperLimit)||
                 (offer.lowerLimit == 0 && offer.upperLimit == 0)) && 
                block.timestamp >= offer.startDate &&  
                block.timestamp <= offer.expire)
            {
                uint256 providerShare;
                uint256 amount = offer.amount;
                uint256 newAmountBalance;

                if (remainOut >= amount) {
                    // amount requested cover whole entry, clear entry
                    remainOut = remainOut.sub(amount);
                    newAmountBalance = offer.amount = 0;
                } else {
                    amount = remainOut;
                    newAmountBalance = offer.amount = offer.amount.sub(remainOut);
                    remainOut = 0;
                }
                providerShare = IOSWAP_RangeFactory(factory).getLiquidityProviderShare(providerStaking[offer.provider]);
                providerShare = tradeFeeCollected.mul(amount).mul(providerShare).div(amountOut.mul(FEE_BASE));
                protocolFeeCollected = protocolFeeCollected.sub(providerShare);
                providerShare = amountInMinusProtocolFee.mul(amount).div(amountOut).add(providerShare);
                offer = offers[!_direction][list[index]];
                offer.reserve = offer.reserve.add(providerShare);
                emit SwappedOneProvider(offer.provider, _direction, amount, providerShare, newAmountBalance, offer.reserve);
            }
            index++;
        }
        }
        require(remainOut == 0, "Amount exceeds available fund");
        emit Swap(to, direction, price, amountIn, amountOut, tradeFeeCollected, protocolFeeCollected);
    }

    function _getOfferList(uint256 offset) internal pure returns(uint256[] memory list, uint256 dataRead) {
        require(msg.data.length >= offset.add(0x40), "Invalid offer list");
        assembly {
            let count := calldataload(add(offset, 0x20))
            let size := mul(count, 0x20)

            if lt(calldatasize(), add(add(offset, 0x40), size)) { // 0x84 (offset) + 0x20 (bytes_size_header) + 0x20 (count) + count*0x20 (list_size)
                revert(0, 0)
            }
            let mark := mload(0x40)
            mstore(0x40, add(mark, add(size, 0x20))) // malloc
            mstore(mark, count) // array length
            calldatacopy(add(mark, 0x20), add(offset, 0x40), size) // copy data to list
            list := mark
            dataRead := add(size, 0x20)
        }
    }

    function sync() external override lock {
        _sync();
    }
    function _sync() internal {
        lastGovBalance = IERC20(govToken).balanceOf(address(this));
        lastToken0Balance = IERC20(token0).balanceOf(address(this));
        lastToken1Balance = IERC20(token1).balanceOf(address(this));
    }

    function redeemProtocolFee() external override lock {
        address protocolFeeTo = IOSWAP_RangeFactory(factory).protocolFeeTo();
        _safeTransfer(token0, protocolFeeTo, protocolFeeBalance0); // optimistically transfer tokens
        _safeTransfer(token1, protocolFeeTo, protocolFeeBalance1); // optimistically transfer tokens
        protocolFeeBalance0 = 0;
        protocolFeeBalance1 = 0;
        _sync();
    }
}