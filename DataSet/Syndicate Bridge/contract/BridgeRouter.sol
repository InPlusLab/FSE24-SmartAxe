// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./library/RLPReader.sol";
import "./library/RToken.sol";
import "./versions/Version0.sol";
import "./interfaces/IBridgeCosignerManager.sol";
import "./interfaces/IBridgeToken.sol";
import "./interfaces/IBridgeTokenManager.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IOwnable.sol";

contract BridgeRouter is
    Version0,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;
    using RToken for RToken.Token;

    mapping(address => uint256) internal _nonces;
    mapping(bytes32 => bool) internal _commitments;

    // ===== initialize override =====
    IBridgeCosignerManager public cosignerManager;
    IBridgeTokenManager public tokenManager;
    uint256 internal _chainId;

    // ===== signing =====
    bytes32 internal constant ENTER_EVENT_SIG =
        keccak256("Enter(address,address,uint256,uint256,uint256,uint256)");

    // ===== proxy =====

    uint256[49] private __gap;

    // ===== fallbacks =====

    receive() external payable {}

    // ===== events =====

    event Enter(
        address indexed token,
        address indexed exitor,
        uint256 amount,
        uint256 nonce,
        uint256 localChainId,
        uint256 targetChainId
    );

    event Exit(
        address indexed token,
        address indexed exitor,
        uint256 amount,
        bytes32 commitment,
        uint256 localChainId,
        uint256 extChainId
    );

    function emitEnter(
        address token,
        address from,
        uint256 amount,
        uint256 targetChainId
    ) internal {
        emit Enter(token, from, amount, _nonces[from], _chainId, targetChainId);
        _nonces[from]++;
    }

    function emitExit(
        address token,
        address to,
        bytes32 commitment,
        uint256 amount,
        uint256 extChainId
    ) internal {
        emit Exit(token, to, amount, commitment, _chainId, extChainId);
    }

    // ===== functionality to update =====

    /**
     * @notice Set the token manager, callable only by cosigners
     * @dev This should be the contract responsible for checking and add tokens to crosschain mapping
     * @param newTokenManager address of token manager contract
     */
    function setTokenManager(address newTokenManager) external onlyOwner {
        require(newTokenManager != address(0), "BR: ZERO_ADDRESS");
        tokenManager = IBridgeTokenManager(newTokenManager);
    }

    /**
     * @notice Set the cosigner manager, callable only by cosigners
     * @dev This should be the contract responsible for sign by behalf of the payloads
     * @param newCosignerManager address of cosigner manager contract
     */
    function setCosignerManager(address newCosignerManager) external onlyOwner {
        require(newCosignerManager != address(0), "BR: ZERO_ADDRESS");
        cosignerManager = IBridgeCosignerManager(newCosignerManager);
    }

    /**
     * @notice Update token info in case of mistake or name re-branding
     * @dev This token should be bridged in order to do this
     * @param token address of bridged token
     * @param newName a new name of token
     * @param newSymbol a new symbol of token
     * @param newDecimals a new decimal of token
     */
    function updateTokenInfo(
        address token,
        string calldata newName,
        string calldata newSymbol,
        uint8 newDecimals
    ) external onlyOwner {
        IBridgeToken(token).updateTokenInfo(newName, newSymbol, newDecimals);
    }

    /**
     * @notice Update token ownership (bor token upgrade and maintenance)
     * @dev This token should be ownable in order to do this
     * @param token address of bridged token
     * @param newOwner new token owner
     */
    function transferTokenOwnership(address token, address newOwner)
        external
        onlyOwner
    {
        IOwnable(token).transferOwnership(newOwner);
    }

    // Initialize function for proxy constructor. Must be used atomically
    function initialize(
        IBridgeCosignerManager cosignerManager_,
        IBridgeTokenManager tokenManager_
    ) public initializer {
        cosignerManager = cosignerManager_;
        tokenManager = tokenManager_;
        assembly {
            sstore(_chainId.slot, chainid())
        }

        // proxy inits
        __Context_init_unchained();
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();
    }

    // enter amount of tokens to protocol
    function enter(
        address token,
        uint256 amount,
        uint256 targetChainId
    ) external nonReentrant whenNotPaused {
        require(token != address(0), "BR: ZERO_ADDRESS");
        require(amount != 0, "BR: ZERO_AMOUNT");

        RToken.Token memory localToken = tokenManager
            .getLocal(token, targetChainId)
            .enter(_msgSender(), address(this), amount);
        emitEnter(localToken.addr, _msgSender(), amount, targetChainId);
    }

    // enter amount of system currency to protocol
    function enterETH(uint256 targetChainId)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        require(msg.value != 0, "BR: ZERO_AMOUNT");
        require(tokenManager.isZero(targetChainId), "BR: NOT_FOUND");

        emitEnter(address(0), _msgSender(), msg.value, targetChainId);
    }

    // exit amount of tokens from protocol
    function exit(bytes calldata data, bytes[] calldata signatures)
        external
        nonReentrant
        whenNotPaused
    {
        RLPReader.RLPItem[] memory logRLPList = data.toRlpItem().toList();
        RLPReader.RLPItem[] memory logTopicRLPList = logRLPList[1].toList(); // topics

        require(
            bytes32(logTopicRLPList[0].toUint()) == ENTER_EVENT_SIG, // topic0 is event sig
            "BR: INVALID_EVT"
        );

        address extTokenAddr = logTopicRLPList[1].toAddress();
        address exitor = logTopicRLPList[2].toAddress();
        require(exitor == _msgSender(), "BR: NOT_ONWER");

        uint256 amount = logRLPList[2].toUint();
        require(amount != 0, "BR: ZERO_AMOUNT");

        uint256 localChainId = logRLPList[5].toUint();
        require(localChainId == _chainId, "BR: WRONG_TARGET_CHAIN");

        uint256 extChainId = logRLPList[4].toUint();
        require(extChainId != _chainId, "BR: WRONG_SOURCE_CHAIN");

        // protected from replay on another network
        bytes32 commitment = keccak256(data);

        require(!_commitments[commitment], "BR: COMMITMENT_KNOWN");
        _commitments[commitment] = true;
        require(
            cosignerManager.verify(commitment, extChainId, signatures),
            "BR: INVALID_SIGNATURES"
        );

        RToken.Token memory localToken = tokenManager
            .getLocal(extTokenAddr, _chainId)
            .exit(address(this), exitor, amount);
        emitExit(localToken.addr, exitor, commitment, amount, extChainId);
    }
}
