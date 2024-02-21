// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;
pragma abicoder v1;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./SyntERC20.sol";
import "./interfaces/ISyntFabric.sol";

/**
 * @title A contract that keeps correspondences between the addresses of real assets of their synthetic representations
 * @dev All function calls are currently implemented without side effects
 * @dev New synth representations can be created by both the factory admin and the creators of the original tokens
 */
contract SyntFabric is OwnableUpgradeable, ISyntFabric {
    /// ** PUBLIC states **
    address public synthesis;
    mapping(bytes32 => address) internal representationSynt;
    mapping(address => address) internal representationReal;

    /// ** EVENTS **

    event RepresentationCreated(
        address rToken,
        uint256 chainID,
        address sToken
    );

    /// ** MODIFIERs **

    modifier onlySynthesis() {
        require(msg.sender == synthesis, "Symb: caller is not the synthesis");
        _;
    }

    /// ** INITIALIZER **

    function initialize(address _synthesis) public virtual initializer {
        __Ownable_init();
        synthesis = _synthesis;
    }

    /// ** PUBLIC functions **

    /**
     * @return address of synt representation
     * @param _key of hashed realTokenAdr and chainID
     */
    function getSyntRepresentationByKey(bytes32 _key)
        public
        view
        returns (address)
    {
        return representationSynt[_key];
    }

    /**
     * @return address of synt representation
     * @param _realTokenAdr address of real token
     * @param _chainID Chain id of the network
     */
    function getSyntRepresentation(address _realTokenAdr, uint256 _chainID)
        public
        view
        override
        returns (address)
    {
        return
            representationSynt[
                keccak256(abi.encodePacked(_realTokenAdr, _chainID))
            ];
    }

    /**
     * @return address of real representation
     * @param _syntTokenAdr address of synt token
     */
    function getRealRepresentation(address _syntTokenAdr)
        public
        view
        override
        returns (address)
    {
        return representationReal[_syntTokenAdr];
    }

    /// ** EXTERNAL functions **
     /**
     * @notice Burns synthetic tokens
     */
    function unsynthesize(
        address _to,
        uint256 _amount,
        address _stoken
    ) external override onlySynthesis {
        SyntERC20(_stoken).burn(_to, _amount);
    }

    /**
     * @notice Mints synthetic tokens
     */
    function synthesize(
        address _to,
        uint256 _amount,
        address _stoken
    ) external override onlySynthesis {
        SyntERC20(_stoken).mint(_to, _amount);
    }

    /// ** ONLYOWNER functions **

    /**
     * @notice function for creation representation by admin
     * @param _rtoken address of real token
     * @param _chainID Chain id of the network
     * @param _stokenName Name of synthetic token
     * @param _stokenSymbol Symbol for synthetic token
     * @param _decimals Decimals value for synthetic token
     */
    function createRepresentationByAdmin(
        address _rtoken,
        uint256 _chainID,
        string memory _stokenName,
        string memory _stokenSymbol,
        uint8 _decimals
    ) external onlyOwner {
        setRepresentation(
            _rtoken,
            _chainID,
            _stokenName,
            _stokenSymbol,
            _decimals
        );
    }

    /// ** INTERNAL functions **

    /**
     * @dev Sets representation
     * @dev Internal function used in createRepresentationByAdmin
     */
    function setRepresentation(
        address _rtoken,
        uint256 _chainID,
        string memory _stokenName,
        string memory _stokenSymbol,
        uint8 _decimals
    ) internal {
        require(_rtoken != address(0), "Symb: rtoken is the zero address");

        address stoken = getSyntRepresentation(_rtoken, _chainID);
        require(
            stoken == address(0x0),
            "Symb: token representation already exists"
        );

        SyntERC20 syntToken = new SyntERC20(
            _stokenName,
            _stokenSymbol,
            _decimals
        );
        representationReal[address(syntToken)] = _rtoken;
        representationSynt[
            keccak256(abi.encodePacked(_rtoken, _chainID))
        ] = address(syntToken);

        emit RepresentationCreated(_rtoken, _chainID, address(syntToken));
    }
}
