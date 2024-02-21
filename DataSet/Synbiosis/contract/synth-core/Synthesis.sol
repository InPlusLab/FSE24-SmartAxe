// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "./interfaces/IBridge.sol";
import "./interfaces/ISyntFabric.sol";
import "../utils/RelayRecipientUpgradeable.sol";
import "./metarouter/interfaces/IMetaRouter.sol";

/**
 * @title A contract that burns (unsynthesizes) tokens
 * @dev All function calls are currently implemented without side effects
 */
contract Synthesis is RelayRecipientUpgradeable {
    /// ** PUBLIC states **

    uint256 public requestCount;
    bool public paused;
    address public bridge;
    address public fabric;
    mapping(bytes32 => SynthesizeState) public synthesizeStates;
    mapping(bytes32 => TxState) public requests;
    mapping(address => uint256) public tokenThreshold;

    IMetaRouter public metaRouter;

    /// ** STRUCTS **

    enum RequestState {
        Default,
        Sent,
        Reverted
    }
    enum SynthesizeState {
        Default,
        Synthesized,
        RevertRequest
    }
    struct TxState {
        address recipient;
        address chain2address;
        uint256 amount;
        address token;
        address stoken;
        RequestState state;
    }

    /// ** EVENTS **

    event BurnRequest(
        bytes32 id,
        address indexed from,
        uint256 indexed chainID,
        address indexed revertableAddress,
        address to,
        uint256 amount,
        address token
    );

    event RevertSynthesizeRequest(bytes32 indexed id, address indexed to);

    event ClientIdLog(bytes32 requestId, bytes32 indexed clientId);

    event SynthesizeCompleted(
        bytes32 indexed id,
        address indexed to,
        uint256 amount,
        uint256 bridgingFee,
        address token
    );

    event RevertBurnCompleted(
        bytes32 indexed id,
        address indexed to,
        uint256 amount,
        uint256 bridgingFee,
        address token
    );

    event Paused(address account);

    event Unpaused(address account);

    event SetTokenThreshold(address token, uint256 threshold);

    event SetMetaRouter(address metaRouter);

    event SetFabric(address fabric);

    /// ** MODIFIERs **

    modifier onlyBridge() {
        require(bridge == msg.sender, "Symb: caller is not the bridge");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Symb: paused");
        _;
    }

    /// ** INITIALIZER **

    /**
     * init
     */
    function initialize(
        address _bridge,
        address _trustedForwarder,
        IMetaRouter _metaRouter
    )
        public
        virtual
        initializer
    {
        __RelayRecipient_init(_trustedForwarder);
        bridge = _bridge;
        metaRouter = _metaRouter;
    }

    /// ** EXTERNAL PURE functions **

    /**
     * @notice Returns version
     */
    function versionRecipient() external pure returns (string memory) {
        return "2.0.1";
    }

    /// ** EXTERNAL functions **

    /**
     * @notice Synthesis contract subcall with synthesis Parameters
     * @dev Can called only by bridge after initiation on a second chain
     * @param _stableBridgingFee Bridging fee
     * @param _externalID the synthesize transaction that was received from the event when it was originally called burn on the Synthesize contract
     * @param _tokenReal The address of the token that the user wants to synthesize
     * @param _chainID Chain id of the network where synthesization will take place
     * @param _amount Number of tokens to synthesize
     * @param _to The address to which the user wants to receive the synth asset on another network
     */
    function mintSyntheticToken(
        uint256 _stableBridgingFee,
        bytes32 _externalID,
        address _tokenReal,
        uint256 _chainID,
        uint256 _amount,
        address _to
    ) external onlyBridge whenNotPaused {
        require(
            synthesizeStates[_externalID] == SynthesizeState.Default,
            "Symb: revertSynthesizedRequest called or tokens have been already synthesized"
        );

        synthesizeStates[_externalID] = SynthesizeState.Synthesized;
        address syntReprAddr = ISyntFabric(fabric).getSyntRepresentation(_tokenReal, _chainID);

        require(syntReprAddr != address(0), "Symb: There is no synt representation for this token");

        ISyntFabric(fabric).synthesize(
            _to,
            _amount - _stableBridgingFee,
            syntReprAddr
        );

        ISyntFabric(fabric).synthesize(
            bridge,
            _stableBridgingFee,
            syntReprAddr
        );
        emit SynthesizeCompleted(_externalID, _to, _amount - _stableBridgingFee, _stableBridgingFee, _tokenReal);
    }

    /**
     * @notice Mint token assets and call second swap and final call
     * @dev Can called only by bridge after initiation on a second chain
     * @param _metaMintTransaction metaMint offchain transaction data
     */
    function metaMintSyntheticToken(
        MetaRouteStructs.MetaMintTransaction memory _metaMintTransaction
    ) external onlyBridge whenNotPaused {
        require(
            synthesizeStates[_metaMintTransaction.externalID] ==
                SynthesizeState.Default,
            "Symb: revertSynthesizedRequest called or tokens have been already synthesized"
        );

        synthesizeStates[_metaMintTransaction.externalID] = SynthesizeState
            .Synthesized;

        address syntReprAddr = ISyntFabric(fabric).getSyntRepresentation(
            _metaMintTransaction.tokenReal,
            _metaMintTransaction.chainID
        );

        require(syntReprAddr != address(0), "Symb: There is no synt representation for this token");

        ISyntFabric(fabric).synthesize(
            address(this),
            _metaMintTransaction.amount - _metaMintTransaction.stableBridgingFee,
            syntReprAddr
        );

        ISyntFabric(fabric).synthesize(
            bridge,
            _metaMintTransaction.stableBridgingFee,
            syntReprAddr
        );

        _metaMintTransaction.amount = _metaMintTransaction.amount - _metaMintTransaction.stableBridgingFee;

        emit SynthesizeCompleted(
            _metaMintTransaction.externalID,
            _metaMintTransaction.to,
            _metaMintTransaction.amount,
            _metaMintTransaction.stableBridgingFee,
            _metaMintTransaction.tokenReal
        );

        if (_metaMintTransaction.swapTokens.length == 0) {
            TransferHelper.safeTransfer(
                syntReprAddr,
                _metaMintTransaction.to,
                _metaMintTransaction.amount
            );
            return;
        }

        // transfer ERC20 tokens to MetaRouter
        TransferHelper.safeTransfer(
            _metaMintTransaction.swapTokens[0],
            address(metaRouter),
            _metaMintTransaction.amount
        );

        // metaRouter swap
        metaRouter.metaMintSwap(_metaMintTransaction);
    }

    /**
     * @notice Revert synthesize() operation
     * @dev Can called only by bridge after initiation on a second chain
     * @dev Further, this transaction also enters the relay network and is called on the other side under the method "revertSynthesize"
     * @param _stableBridgingFee Bridging fee on another network
     * @param _internalID the synthesize transaction that was received from the event when it was originally called synthesize on the Portal contract
     * @param _receiveSide Synthesis address on another network
     * @param _oppositeBridge Bridge address on another network
     * @param _chainID Chain id of the network
     */
    function revertSynthesizeRequest(
        uint256 _stableBridgingFee,
        bytes32 _internalID,
        address _receiveSide,
        address _oppositeBridge,
        uint256 _chainID,
        bytes32 _clientID
    ) external whenNotPaused {
        bytes32 externalID = keccak256(abi.encodePacked(_internalID, address(this), _msgSender(), block.chainid));

        require(
            synthesizeStates[externalID] != SynthesizeState.Synthesized,
            "Symb: synthetic tokens already minted"
        );
        synthesizeStates[externalID] = SynthesizeState.RevertRequest; // close

        {
            bytes memory out = abi.encodeWithSelector(
                bytes4(keccak256(bytes("revertSynthesize(uint256,bytes32)"))),
                _stableBridgingFee,
                externalID
            );
            IBridge(bridge).transmitRequestV2(
                out,
                _receiveSide,
                _oppositeBridge,
                _chainID
            );
        }

        emit RevertSynthesizeRequest(_internalID, _msgSender());
        emit ClientIdLog(_internalID, _clientID);
    }

    function revertSynthesizeRequestByBridge(
        uint256 _stableBridgingFee,
        bytes32 _internalID,
        address _receiveSide,
        address _oppositeBridge,
        uint256 _chainID,
        address _sender,
        bytes32 _clientID
    ) external whenNotPaused onlyBridge{
        bytes32 externalID = keccak256(abi.encodePacked(_internalID, address(this), _sender, block.chainid));
        require(
            synthesizeStates[externalID] != SynthesizeState.Synthesized,
            "Symb: synthetic tokens already minted"
        );
        synthesizeStates[externalID] = SynthesizeState.RevertRequest; // close

        {
            bytes memory out = abi.encodeWithSelector(
                bytes4(keccak256(bytes("revertSynthesize(uint256,bytes32)"))),
                _stableBridgingFee,
                externalID
            );
            IBridge(bridge).transmitRequestV2(
                out,
                _receiveSide,
                _oppositeBridge,
                _chainID
            );
        }
        emit ClientIdLog(_internalID, _clientID);
        emit RevertSynthesizeRequest(_internalID, _sender);
    }

    /**
     * @notice Sends burn request
     * @dev sToken -> Token on a second chain
     * @param _stableBridgingFee Bridging fee on another network
     * @param _stoken The address of the token that the user wants to burn
     * @param _amount Number of tokens to burn
     * @param _chain2address The address to which the user wants to receive tokens
     * @param _receiveSide Synthesis address on another network
     * @param _oppositeBridge Bridge address on another network
     * @param _revertableAddress An address on another network that allows the user to revert a stuck request
     * @param _chainID Chain id of the network where burning will take place
     */
    function burnSyntheticToken(
        uint256 _stableBridgingFee,
        address _stoken,
        uint256 _amount,
        address _chain2address,
        address _receiveSide,
        address _oppositeBridge,
        address _revertableAddress,
        uint256 _chainID,
        bytes32 _clientID
    ) external whenNotPaused returns (bytes32 internalID) {
        require(_amount >= tokenThreshold[_stoken], "Symb: amount under threshold");
        ISyntFabric(fabric).unsynthesize(_msgSender(), _amount, _stoken);
        if (_revertableAddress == address(0)) {
            _revertableAddress = _chain2address;
        }

        {
            address rtoken = ISyntFabric(fabric).getRealRepresentation(_stoken);
            require(rtoken != address(0), "Symb: incorrect synt");

            internalID = keccak256(
                abi.encodePacked(this, requestCount, block.chainid)
            );
            bytes32 externalID = keccak256(abi.encodePacked(internalID, _receiveSide, _revertableAddress, _chainID));

            bytes memory out = abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        bytes("unsynthesize(uint256,bytes32,address,uint256,address)")
                    )
                ),
                _stableBridgingFee,
                externalID,
                rtoken,
                _amount,
                _chain2address
            );

            requests[externalID] = TxState({
                recipient: _msgSender(),
                chain2address: _chain2address,
                token: rtoken,
                stoken: _stoken,
                amount: _amount,
                state: RequestState.Sent
            });

            requestCount++;

            IBridge(bridge).transmitRequestV2(
                out,
                _receiveSide,
                _oppositeBridge,
                _chainID
            );
        }
        emit BurnRequest(internalID, _msgSender(), _chainID, _revertableAddress, _chain2address, _amount, _stoken);
        emit ClientIdLog(internalID, _clientID);
    }

    /**
     * @notice Sends metaBurn request
     * @dev sToken -> Token -> finalToken on a second chain
     * @param _metaBurnTransaction metaBurn transaction data
     */
    function metaBurnSyntheticToken(
        MetaRouteStructs.MetaBurnTransaction memory _metaBurnTransaction
    ) external whenNotPaused returns (bytes32 internalID) {
        require(_metaBurnTransaction.amount >= tokenThreshold[_metaBurnTransaction.sToken], "Symb: amount under threshold");

        ISyntFabric(fabric).unsynthesize(
            _msgSender(),
            _metaBurnTransaction.amount,
            _metaBurnTransaction.sToken
        );

        if (_metaBurnTransaction.revertableAddress == address(0)) {
            _metaBurnTransaction.revertableAddress = _metaBurnTransaction.chain2address;
        }

        {
            address rtoken = ISyntFabric(fabric).getRealRepresentation(
                _metaBurnTransaction.sToken
            );
            require(rtoken != address(0), "Symb: incorrect synt");

            internalID = keccak256(
                abi.encodePacked(this, requestCount, block.chainid)
            );
            bytes32 externalID = keccak256(abi.encodePacked(internalID, _metaBurnTransaction.receiveSide, _metaBurnTransaction.revertableAddress, _metaBurnTransaction.chainID)); // external ID
            bytes memory out = abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        bytes(
                            "metaUnsynthesize(uint256,bytes32,address,uint256,address,address,bytes,uint256)"
                        )
                    )
                ),
                _metaBurnTransaction.stableBridgingFee,
                externalID,
                _metaBurnTransaction.chain2address,
                _metaBurnTransaction.amount,
                rtoken,
                _metaBurnTransaction.finalReceiveSide,
                _metaBurnTransaction.finalCallData,
                _metaBurnTransaction.finalOffset
            );

            requests[externalID] = TxState({
                recipient: _metaBurnTransaction.syntCaller,
                chain2address: _metaBurnTransaction.chain2address,
                token: rtoken,
                stoken: _metaBurnTransaction.sToken,
                amount: _metaBurnTransaction.amount,
                state: RequestState.Sent
            });

            requestCount++;
            IBridge(bridge).transmitRequestV2(
                out,
                _metaBurnTransaction.receiveSide,
                _metaBurnTransaction.oppositeBridge,
                _metaBurnTransaction.chainID
            );
        }

        emit BurnRequest(
            internalID,
            _metaBurnTransaction.syntCaller,
            _metaBurnTransaction.chainID,
            _metaBurnTransaction.revertableAddress,
            _metaBurnTransaction.chain2address,
            _metaBurnTransaction.amount,
            _metaBurnTransaction.sToken
        );
        emit ClientIdLog(internalID, _metaBurnTransaction.clientID);
    }

    /**
     * @notice Emergency unburn
     * @dev Can called only by bridge after initiation on a second chain
     * @param _stableBridgingFee Bridging fee 
     * @param _externalID the synthesize transaction that was received from the event when it was originally called burn on the Synthesize contract
     */
    function revertBurn(uint256 _stableBridgingFee, bytes32 _externalID) external onlyBridge whenNotPaused {
        TxState storage txState = requests[_externalID];
        require(
            txState.state == RequestState.Sent,
            "Symb: state not open or tx does not exist"
        );
        txState.state = RequestState.Reverted;
        // close
        ISyntFabric(fabric).synthesize(
            txState.recipient,
            txState.amount - _stableBridgingFee,
            txState.stoken
        );
        ISyntFabric(fabric).synthesize(
            bridge,
            _stableBridgingFee,
            txState.stoken
        );
        emit RevertBurnCompleted(
            _externalID,
            txState.recipient,
            txState.amount - _stableBridgingFee,
            _stableBridgingFee,
            txState.stoken
        );
    }

    function revertBurnAndBurn(uint256 _stableBridgingFee, bytes32 _externalID, address _receiveSide, address _oppositeBridge, uint256 _chainID, address _revertableAddress) external onlyBridge whenNotPaused {
        TxState storage txState = requests[_externalID];
        require(
            txState.state == RequestState.Sent,
            "Symb: state not open or tx does not exist"
        );
        txState.state = RequestState.Reverted;
        // close
        ISyntFabric(fabric).synthesize(
            bridge,
            _stableBridgingFee,
            txState.stoken
        );
        uint256 amount = txState.amount - _stableBridgingFee;
        emit RevertBurnCompleted(
            _externalID,
            txState.recipient,
            amount,
            _stableBridgingFee,
            txState.stoken
        );

        if (_revertableAddress == address(0)) {
            _revertableAddress = txState.chain2address;
        }

        address rtoken = ISyntFabric(fabric).getRealRepresentation(txState.stoken);
        bytes32 internalID = keccak256(
            abi.encodePacked(this, requestCount, block.chainid)
        );
        bytes32 externalID = keccak256(abi.encodePacked(internalID, _receiveSide, _revertableAddress, _chainID));

        bytes memory out = abi.encodeWithSelector(
            bytes4(
                keccak256(
                    bytes("unsynthesize(uint256,bytes32,address,uint256,address)")
                )
            ),
            _stableBridgingFee,
            externalID,
            rtoken,
            amount,
            txState.chain2address
        );

        requests[externalID] = TxState({
        recipient: _msgSender(),
        chain2address: txState.chain2address,
        token: rtoken,
        stoken: txState.stoken,
        amount: amount,
        state: RequestState.Sent
        });

        requestCount++;

        IBridge(bridge).transmitRequestV2(
            out,
            _receiveSide,
            _oppositeBridge,
            _chainID
        );

        emit BurnRequest(internalID, _msgSender(), _chainID, _revertableAddress, txState.chain2address, amount, txState.stoken);
    }

    function revertMetaBurn(
        uint256 _stableBridgingFee, 
        bytes32 _externalID, 
        address _router, 
        bytes calldata _swapCalldata,
        address _synthesis,
        address _burnToken,
        bytes calldata _burnCalldata
        ) external onlyBridge whenNotPaused {
        TxState storage txState = requests[_externalID];
        require(
            txState.state == RequestState.Sent,
            "Symb: state not open or tx does not exist"
        );
        txState.state = RequestState.Reverted;
        // close    
        ISyntFabric(fabric).synthesize(
            txState.recipient,
            txState.amount - _stableBridgingFee,
            txState.stoken
        );
        ISyntFabric(fabric).synthesize(
            bridge,
            _stableBridgingFee,
            txState.stoken
        );

        IMetaRouter(metaRouter).returnSwap(txState.stoken, txState.amount - _stableBridgingFee, _router, _swapCalldata, _burnToken, _synthesis, _burnCalldata);

        emit RevertBurnCompleted(
            _externalID,
            txState.recipient,
            txState.amount - _stableBridgingFee,
            _stableBridgingFee,
            txState.stoken
        );
    }

    /// ** ONLYOWNER functions **

    /**
     * @notice Set paused flag to true
     */
    function pause() external onlyOwner {
        paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @notice Set paused flag to false
     */
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(_msgSender());
    }

    /**
     * @notice Sets minimal price for token
     * @param _token Address of token to set threshold
     * @param _threshold threshold to set
     */
    function setTokenThreshold(address _token, uint256 _threshold) external onlyOwner {
        tokenThreshold[_token] = _threshold;
        emit SetTokenThreshold(_token, _threshold);
    }

    /**
     * @notice Sets MetaRouter address
     * @param _metaRouter Address of metaRouter
     */
    function setMetaRouter(IMetaRouter _metaRouter) external onlyOwner {
        require(address(_metaRouter) != address(0), "Symb: metaRouter cannot be zero address");
        metaRouter = _metaRouter;
        emit SetMetaRouter(address(_metaRouter));
    }

    /**
     * @notice Sets Fabric address
     * @param _fabric Address of fabric
     */
    function setFabric(address _fabric) external onlyOwner {
        require(fabric == address(0x0), "Symb: Fabric already set");
        fabric = _fabric;
        emit SetFabric(_fabric);
    }
}