// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/ISolarERC20.sol";
import "./interfaces/ISolarPair.sol";
import "./interfaces/ISolarFactory.sol";

contract SolarBurner is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    ISolarFactory public immutable factory;
    address public immutable burner;
    address private immutable solar;
    address private immutable wmovr;

    mapping(address => address) internal _bridges;

    event LogBridgeSet(address indexed token, address indexed bridge);

    event LogConvert(
        address indexed server,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 amountSOLAR
    );

    constructor(
        address _factory,
        address _burner,
        address _solar,
        address _wmovr
    ) {
        factory = ISolarFactory(_factory);
        burner = _burner;
        solar = _solar;
        wmovr = _wmovr;
    }

    function bridgeFor(address token) public view returns (address bridge) {
        bridge = _bridges[token];
        if (bridge == address(0)) {
            bridge = wmovr;
        }
    }

    function setBridge(address token, address bridge) external onlyOwner {
        // Checks
        require(
            token != solar && token != wmovr && token != bridge,
            "SolarBurner: Invalid bridge"
        );

        // Effects
        _bridges[token] = bridge;
        emit LogBridgeSet(token, bridge);
    }

    // It's not a fool proof solution, but it prevents flash loans, so here it's ok to use tx.origin
    modifier onlyEOA() {
        // Try to make flash-loan exploit harder to do by only allowing externally owned addresses.
        require(msg.sender == tx.origin, "SolarBurner: must use EOA");
        _;
    }

    // _convert is separate to save gas by only checking the 'onlyEOA' modifier once in case of convertMultiple
    function convert(address token0, address token1) external onlyEOA {
        _convert(token0, token1);
    }

    function convertMultiple(
        address[] calldata token0,
        address[] calldata token1
    ) external onlyEOA {
        uint256 len = token0.length;
        for (uint256 i = 0; i < len; i++) {
            _convert(token0[i], token1[i]);
        }
    }

    function _convert(address token0, address token1) internal {
        ISolarPair pair = ISolarPair(factory.getPair(token0, token1));
        require(address(pair) != address(0), "SolarBurner: Invalid pair");
        IERC20(address(pair)).safeTransfer(
            address(pair),
            pair.balanceOf(address(this))
        );
        (uint256 amount0, uint256 amount1) = pair.burn(address(this));
        if (token0 != pair.token0()) {
            (amount0, amount1) = (amount1, amount0);
        }
        emit LogConvert(
            msg.sender,
            token0,
            token1,
            amount0,
            amount1,
            _convertStep(token0, token1, amount0, amount1)
        );
    }

    // All safeTransfer, _swap, _toSOLAR, _convertStep: X1 - X5: OK
    function _convertStep(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 solarOut) {
        if (token0 == token1) {
            uint256 amount = amount0.add(amount1);
            if (token0 == solar) {
                IERC20(solar).safeTransfer(burner, amount);
                solarOut = amount;
            } else if (token0 == wmovr) {
                solarOut = _toSOLAR(wmovr, amount);
            } else {
                address bridge = bridgeFor(token0);
                amount = _swap(token0, bridge, amount, address(this));
                solarOut = _convertStep(bridge, bridge, amount, 0);
            }
        } else if (token0 == solar) {
            IERC20(solar).safeTransfer(burner, amount0);
            solarOut = _toSOLAR(token1, amount1).add(amount0);
        } else if (token1 == solar) {
            // eg. USDC - SOLAR
            IERC20(solar).safeTransfer(burner, amount1);
            solarOut = _toSOLAR(token0, amount0).add(amount1);
        } else if (token0 == wmovr) {
            // eg. ETH - USDC
            solarOut = _toSOLAR(
                wmovr,
                _swap(token1, wmovr, amount1, address(this)).add(amount0)
            );
        } else if (token1 == wmovr) {
            // eg. USDC - MOVR
            solarOut = _toSOLAR(
                wmovr,
                _swap(token0, wmovr, amount0, address(this)).add(amount1)
            );
        } else {
            // eg. MIM - USDC
            address bridge0 = bridgeFor(token0);
            address bridge1 = bridgeFor(token1);
            if (bridge0 == token1) {
                // eg. MIM - USDC - and bridgeFor(MIM) = USDC
                solarOut = _convertStep(
                    bridge0,
                    token1,
                    _swap(token0, bridge0, amount0, address(this)),
                    amount1
                );
            } else if (bridge1 == token0) {
                // eg. WBTC - WETH - and bridgeFor(WETH) = WBTC
                solarOut = _convertStep(
                    token0,
                    bridge1,
                    amount0,
                    _swap(token1, bridge1, amount1, address(this))
                );
            } else {
                solarOut = _convertStep(
                    bridge0,
                    bridge1, // eg. USDC - WETH - and bridgeFor(WETH) = WBTC
                    _swap(token0, bridge0, amount0, address(this)),
                    _swap(token1, bridge1, amount1, address(this))
                );
            }
        }
    }

    function _swap(
        address fromToken,
        address toToken,
        uint256 amountIn,
        address to
    ) internal returns (uint256 amountOut) {
        ISolarPair pair = ISolarPair(factory.getPair(fromToken, toToken));
        require(address(pair) != address(0), "SolarBurner: Cannot convert");

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 amountInWithFee = amountIn.mul(997);
        if (fromToken == pair.token0()) {
            amountOut =
                amountInWithFee.mul(reserve1) /
                reserve0.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(0, amountOut, to, new bytes(0));
        } else {
            amountOut =
                amountInWithFee.mul(reserve0) /
                reserve1.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(amountOut, 0, to, new bytes(0));
        }
    }

    function _toSOLAR(address token, uint256 amountIn)
        internal
        returns (uint256 amountOut)
    {
        amountOut = _swap(token, solar, amountIn, burner);
    }
}
