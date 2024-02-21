// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.6.11;

import '../../commons/interfaces/IOSWAP_PausablePair.sol';

interface IOSWAP_OraclePair is IOSWAP_PausablePair {
    struct Offer {
        address provider;
        uint256 staked;
        uint256 amount;
        uint256 reserve;
        uint256 expire;
        bool privateReplenish;
        bool isActive;
        bool enabled;
        uint256 prev;
        uint256 next;
    }

    event NewProvider(address indexed provider, uint256 index);
    event AddLiquidity(address indexed provider, bool indexed direction, uint256 staked, uint256 amount, uint256 newStakeBalance, uint256 newAmountBalance, uint256 expire, bool enable);
    event Replenish(address indexed provider, bool indexed direction, uint256 amountIn, uint256 newAmountBalance, uint256 newReserveBalance, uint256 expire);
    event RemoveLiquidity(address indexed provider, bool indexed direction, uint256 unstake, uint256 amountOut, uint256 reserveOut, uint256 newStakeBalance, uint256 newAmountBalance, uint256 newReserveBalance, uint256 expire, bool enable);
    event Swap(address indexed to, bool indexed direction, uint256 price, uint256 amountIn, uint256 amountOut, uint256 tradeFee, uint256 protocolFee);
    event SwappedOneProvider(address indexed provider, bool indexed direction, uint256 amountOut, uint256 amountIn, uint256 newAmountBalance, uint256 newCounterReserveBalance);
    event SetDelegator(address indexed provider, address delegator);
    event DelegatorPauseOffer(address indexed delegator, address indexed provider, bool indexed direction);
    event DelegatorResumeOffer(address indexed delegator, address indexed provider, bool indexed direction);

    function counter() external view returns (uint256);
    function first(bool direction) external view returns (uint256);
    function queueSize(bool direction) external view returns (uint256);
    function offers(bool direction, uint256 index) external view returns (
        address provider,
        uint256 staked,
        uint256 amount,
        uint256 reserve,
        uint256 expire,
        bool privateReplenish,
        bool isActive,
        bool enabled,
        uint256 prev,
        uint256 next
    );
    function providerOfferIndex(address provider) external view returns (uint256 index);
    function delegator(address provider) external view returns (address);

    function governance() external view returns (address);
    function oracleLiquidityProvider() external view returns (address);
    function govToken() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function scaleDirection() external view returns (bool);
    function scaler() external view returns (uint256);

    function lastGovBalance() external view returns (uint256);
    function lastToken0Balance() external view returns (uint256);
    function lastToken1Balance() external view returns (uint256);
    function protocolFeeBalance0() external view returns (uint256);
    function protocolFeeBalance1() external view returns (uint256);
    function stakeBalance() external view returns (uint256);
    function feeBalance() external view returns (uint256);

    function getLastBalances() external view returns (uint256, uint256);
    function getBalances() external view returns (uint256, uint256, uint256);

    function getLatestPrice(bool direction, bytes calldata payload) external view returns (uint256);
    function getAmountOut(address tokenIn, uint256 amountIn, bytes calldata data) external view returns (uint256 amountOut);
    function getAmountIn(address tokenOut, uint256 amountOut, bytes calldata data) external view returns (uint256 amountIn);

    function setDelegator(address _delegator, uint256 fee) external;

    function getQueue(bool direction, uint256 start, uint256 end) external view returns (uint256[] memory index, address[] memory provider, uint256[] memory amount, uint256[] memory staked, uint256[] memory expire);
    function getQueueFromIndex(bool direction, uint256 from, uint256 count) external view returns (uint256[] memory index, address[] memory provider, uint256[] memory amount, uint256[] memory staked, uint256[] memory expire);
    function getProviderOffer(address _provider, bool direction) external view returns (uint256 index, uint256 staked, uint256 amount, uint256 reserve, uint256 expire, bool privateReplenish);
    function findPosition(bool direction, uint256 staked, uint256 _afterIndex) external view returns (uint256 afterIndex, uint256 nextIndex);
    function addLiquidity(address provider, bool direction, uint256 staked, uint256 afterIndex, uint256 expire, bool enable) external returns (uint256 index);
    function setPrivateReplenish(bool _replenish) external;
    function replenish(address provider, bool direction, uint256 afterIndex, uint amountIn, uint256 expire) external;
    function pauseOffer(address provider, bool direction) external;
    function resumeOffer(address provider, bool direction, uint256 afterIndex) external;
    function removeLiquidity(address provider, bool direction, uint256 unstake, uint256 afterIndex, uint256 amountOut, uint256 reserveOut, uint256 expire, bool enable) external;
    function removeAllLiquidity(address provider) external returns (uint256 amount0, uint256 amount1, uint256 staked);
    function purgeExpire(bool direction, uint256 startingIndex, uint256 limit) external returns (uint256 purge);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function sync() external;

    function initialize(address _token0, address _token1) external;
    function redeemProtocolFee() external;
}