// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/ISolarERC20.sol";
import "./interfaces/ISolarPair.sol";
import "./interfaces/ISolarFactory.sol";
import "./interfaces/ISolarRouter02.sol";
import "./interfaces/ISmartRouter.sol";

contract SolarFeeColector is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    uint256 internal constant UINT_MAX = type(uint256).max;

    ISmartRouter public smartRouter;
    ISolarRouter02 public router;
    address private immutable wmovr;

    constructor(
        address _smartRouter,
        address _router,
        address _wmovr
    ) {
        smartRouter = ISmartRouter(_smartRouter);
        router = ISolarRouter02(_router);
        wmovr = _wmovr;
    }

    function removeLiquidityAndSwap(address[] memory lpTokens, address toToken)
        external
        onlyOwner
    {
        uint256 len = lpTokens.length;
        for (uint256 i = 0; i < len; i++) {
            ISolarPair pair = ISolarPair(lpTokens[i]);
            address token0 = ISolarPair(pair).token0();
            address token1 = ISolarPair(pair).token1();

            _removeLiquidity(address(pair), address(this));
            _swap(token0, toToken, address(this));
            _swap(token1, toToken, address(this));
        }
    }

    function removeLiquidity(address[] memory lpTokens) external onlyOwner {
        uint256 len = lpTokens.length;
        for (uint256 i = 0; i < len; i++) {
            _removeLiquidity(lpTokens[i], address(this));
        }
    }

    function removeLiquidityFrom(address[] memory lpTokens) external onlyOwner {
        uint256 len = lpTokens.length;
        for (uint256 i = 0; i < len; i++) {
            _removeLiquidity(lpTokens[i], msg.sender);
        }
    }

    function _removeLiquidity(address lpToken, address from) internal {
        ISolarPair pair = ISolarPair(lpToken);
        address token0 = ISolarPair(lpToken).token0();
        address token1 = ISolarPair(lpToken).token1();
        require(address(pair) != address(0), "SolarFeeColector: Invalid pair");

        uint256 amount = IERC20(address(pair)).balanceOf(from);

        if (amount > 0) {
            if (from != address(this)) {
                IERC20(address(pair)).safeTransferFrom(
                    from,
                    address(this),
                    amount
                );
            }

            if (
                IERC20(lpToken).allowance(address(this), address(router)) <
                amount
            ) {
                IERC20(lpToken).safeApprove(address(router), UINT_MAX);
            }

            router.removeLiquidity(
                token0,
                token1,
                amount,
                0,
                0,
                msg.sender,
                block.timestamp
            );
        }
    }

    function swapTokens(address[] memory tokens, address toToken)
        external
        onlyOwner
    {
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
            _swap(tokens[i], toToken, address(this));
        }
    }

    function swapTokensFrom(address[] memory tokens, address toToken)
        external
        onlyOwner
    {
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
            _swap(tokens[i], toToken, msg.sender);
        }
    }

    function _swap(
        address fromToken,
        address toToken,
        address from
    ) internal {
        uint256 amount = IERC20(address(fromToken)).balanceOf(from);

        if (amount > 0) {
            if (from != address(this)) {
                IERC20(address(fromToken)).safeTransferFrom(
                    from,
                    address(this),
                    amount
                );
            }

            if (
                IERC20(fromToken).allowance(
                    address(this),
                    address(smartRouter)
                ) < amount
            ) {
                IERC20(fromToken).safeApprove(address(smartRouter), UINT_MAX);
            }

            ISmartRouter.FormattedOffer memory offer = smartRouter.findBestPath(
                amount,
                fromToken,
                toToken,
                3,
                ISmartRouter.InputType.AMOUNT_IN
            );

            ISmartRouter.Trade memory trade = ISmartRouter.Trade(
                offer.amounts,
                offer.path,
                offer.adapters
            );

            smartRouter.swapNoSplit(trade, msg.sender, 0);
        }
    }

    receive() external payable {}

    function recoverERC20(address _tokenAddress, uint256 _tokenAmount)
        external
        onlyOwner
    {
        require(_tokenAmount > 0, "Nothing to recover");
        IERC20(_tokenAddress).safeTransfer(msg.sender, _tokenAmount);
    }

    function recoverNATIVE(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Nothing to recover");
        payable(msg.sender).transfer(_amount);
    }
}
