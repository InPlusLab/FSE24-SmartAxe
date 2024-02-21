// SPDX-License-Identifier: UNLICENSED
/*

                         ┌───────────┐
                         │ HOLOGRAPH │
                         └───────────┘
╔═════════════════════════════════════════════════════════════╗
║                                                             ║
║                            / ^ \                            ║
║                            ~~*~~            ¸               ║
║                         [ '<>:<>' ]         │░░░            ║
║               ╔╗           _/"\_           ╔╣               ║
║             ┌─╬╬─┐          """          ┌─╬╬─┐             ║
║          ┌─┬┘ ╠╣ └┬─┐       \_/       ┌─┬┘ ╠╣ └┬─┐          ║
║       ┌─┬┘ │  ╠╣  │ └┬─┐           ┌─┬┘ │  ╠╣  │ └┬─┐       ║
║    ┌─┬┘ │  │  ╠╣  │  │ └┬─┐     ┌─┬┘ │  │  ╠╣  │  │ └┬─┐    ║
║ ┌─┬┘ │  │  │  ╠╣  │  │  │ └┬┐ ┌┬┘ │  │  │  ╠╣  │  │  │ └┬─┐ ║
╠┬┘ │  │  │  │  ╠╣  │  │  │  │└¤┘│  │  │  │  ╠╣  │  │  │  │ └┬╣
║│  │  │  │  │  ╠╣  │  │  │  │   │  │  │  │  ╠╣  │  │  │  │  │║
╠╩══╩══╩══╩══╩══╬╬══╩══╩══╩══╩═══╩══╩══╩══╩══╬╬══╩══╩══╩══╩══╩╣
╠┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴╬╬┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴╬╬┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴╣
║               ╠╣                           ╠╣               ║
║               ╠╣                           ╠╣               ║
║    ,          ╠╣     ,        ,'      *    ╠╣               ║
║~~~~~^~~~~~~~~┌╬╬┐~~~^~~~~~~~~^^~~~~~~~~^~~┌╬╬┐~~~~~~~^~~~~~~║
╚══════════════╩╩╩╩═════════════════════════╩╩╩╩══════════════╝
     - one protocol, one bridge = infinite possibilities -


 ***************************************************************

 DISCLAIMER: U.S Patent Pending

 LICENSE: Holograph Limited Public License (H-LPL)

 https://holograph.xyz/licenses/h-lpl/1.0.0

 This license governs use of the accompanying software. If you
 use the software, you accept this license. If you do not accept
 the license, you are not permitted to use the software.

 1. Definitions

 The terms "reproduce," "reproduction," "derivative works," and
 "distribution" have the same meaning here as under U.S.
 copyright law. A "contribution" is the original software, or
 any additions or changes to the software. A "contributor" is
 any person that distributes its contribution under this
 license. "Licensed patents" are a contributor’s patent claims
 that read directly on its contribution.

 2. Grant of Rights

 A) Copyright Grant- Subject to the terms of this license,
 including the license conditions and limitations in sections 3
 and 4, each contributor grants you a non-exclusive, worldwide,
 royalty-free copyright license to reproduce its contribution,
 prepare derivative works of its contribution, and distribute
 its contribution or any derivative works that you create.
 B) Patent Grant- Subject to the terms of this license,
 including the license conditions and limitations in section 3,
 each contributor grants you a non-exclusive, worldwide,
 royalty-free license under its licensed patents to make, have
 made, use, sell, offer for sale, import, and/or otherwise
 dispose of its contribution in the software or derivative works
 of the contribution in the software.

 3. Conditions and Limitations

 A) No Trademark License- This license does not grant you rights
 to use any contributors’ name, logo, or trademarks.
 B) If you bring a patent claim against any contributor over
 patents that you claim are infringed by the software, your
 patent license from such contributor is terminated with
 immediate effect.
 C) If you distribute any portion of the software, you must
 retain all copyright, patent, trademark, and attribution
 notices that are present in the software.
 D) If you distribute any portion of the software in source code
 form, you may do so only under this license by including a
 complete copy of this license with your distribution. If you
 distribute any portion of the software in compiled or object
 code form, you may only do so under a license that complies
 with this license.
 E) The software is licensed “as-is.” You bear all risks of
 using it. The contributors give no express warranties,
 guarantees, or conditions. You may have additional consumer
 rights under your local laws which this license cannot change.
 To the extent permitted under your local laws, the contributors
 exclude all implied warranties, including those of
 merchantability, fitness for a particular purpose and
 non-infringement.

 4. (F) Platform Limitation- The licenses granted in sections
 2.A & 2.B extend only to the software or derivative works that
 you create that run on a Holograph system product.

 ***************************************************************

*/

pragma solidity 0.8.13;

import "../abstract/Admin.sol";
import "../abstract/Initializable.sol";
import "../abstract/Owner.sol";

import "../interface/ERC20.sol";
import "../interface/HolographerInterface.sol";
import "../interface/InitializableInterface.sol";
import "../interface/HolographRoyaltiesInterface.sol";

import "../struct/ZoraBidShares.sol";

/**
 * @title HolographRoyalties
 * @author Holograph Foundation
 * @notice A smart contract for providing royalty info, collecting royalties, and distributing it to configured payout wallets.
 * @dev This smart contract is not intended to be used directly. Apply it to any of your ERC721 or ERC1155 smart contracts through a delegatecall fallback.
 */
contract HolographRoyalties is Admin, Owner, Initializable {
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.ROYALTIES.defaultBp')) - 1)
   */
  bytes32 constant _defaultBpSlot = 0xff29fcf645501423fd56e0287670f6813a1e5db5cf706428bc8516381e7ffe81;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.ROYALTIES.defaultReceiver')) - 1)
   */
  bytes32 constant _defaultReceiverSlot = 0x00b381815b89a20a37ee91e8a0119be5e16f6d1668377e7ae457213a74a415bb;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.ROYALTIES.initialized')) - 1)
   */
  bytes32 constant _initializedPaidSlot = 0x91428d26cb4818e4e627ebb64c06b5a67b82f313516b5c903cf07a00681c95f6;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.ROYALTIES.payout.addresses')) - 1)
   */
  bytes32 constant _payoutAddressesSlot = 0xf31f2a3a453a7aa2f3054423a8c5474ac9817ea457b458152967bbcb12ed6a43;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.ROYALTIES.payout.bps')) - 1)
   */
  bytes32 constant _payoutBpsSlot = 0xa4023567d5b5f01c63e00d90785d7cd4ff057a237ad185c5ecade8f4059fb61a;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.ROYALTIES.extendedCall')) - 1)
   * @dev extendedCall is an init config used to determine if payouts should be sent via a call or a transfer.
   */
  bytes32 constant _extendedCallSlot = 0x254926eafdecb56f669f96a3a752fbca17becd902481431df613768b1f903fa3;

  string constant _bpString = "eip1967.Holograph.ROYALTIES.bp";
  string constant _receiverString = "eip1967.Holograph.ROYALTIES.receiver";
  string constant _tokenAddressString = "eip1967.Holograph.ROYALTIES.tokenAddress";

  /**
   * @notice Event emitted when setting/updating royalty info/fees. This is used by Rarible V1.
   * @dev Emits event in order to comply with Rarible V1 royalty spec.
   * @param tokenId Specific token id for which royalty info is being set, set as 0 for all tokens inside of the smart contract.
   * @param recipients Address array of wallets that will receive tha royalties.
   * @param bps Uint256 array of base points(percentages) that each wallet(specified in recipients) will receive from the royalty payouts.
   *            Make sure that all the base points add up to a total of 10000.
   */
  event SecondarySaleFees(uint256 tokenId, address[] recipients, uint256[] bps);

  /**
   * @dev Use this modifier to lock public functions that should not be accesible to non-owners.
   */
  modifier onlyOwner() override {
    require(isOwner(), "ROYALTIES: caller not an owner");
    _;
  }

  /**
   * @dev Constructor is left empty and init is used instead
   */
  constructor() {}

  /**
   * @notice Used internally to initialize the contract instead of through a constructor
   * @dev This function is called by the deployer/factory when creating a contract
   * @param initPayload abi encoded payload to use for contract initilaization
   */
  function init(bytes memory initPayload) external override returns (bytes4) {
    require(!_isInitialized(), "ROYALTIES: already initialized");
    assembly {
      sstore(_adminSlot, caller())
      sstore(_ownerSlot, caller())
    }
    uint256 bp = abi.decode(initPayload, (uint256));
    setRoyalties(0, payable(address(this)), bp);
    _setInitialized();
    return InitializableInterface.init.selector;
  }

  function initHolographRoyalties(bytes memory initPayload) external returns (bytes4) {
    uint256 initialized;
    assembly {
      initialized := sload(_initializedPaidSlot)
    }
    require(initialized == 0, "ROYALTIES: already initialized");
    (uint256 bp, uint256 useExtenededCall) = abi.decode(initPayload, (uint256, uint256));
    if (useExtenededCall > 0) {
      useExtenededCall = 1;
    }
    assembly {
      sstore(_extendedCallSlot, useExtenededCall)
    }
    setRoyalties(0, payable(address(this)), bp);
    address payable[] memory addresses = new address payable[](1);
    addresses[0] = payable(Owner(HolographerInterface(address(this)).getSourceContract()).owner());
    uint256[] memory bps = new uint256[](1);
    bps[0] = 10000;
    _setPayoutAddresses(addresses);
    _setPayoutBps(bps);
    initialized = 1;
    assembly {
      sstore(_initializedPaidSlot, initialized)
    }
    return InitializableInterface.init.selector;
  }

  /**
   * @notice Check if message sender is a legitimate owner of the smart contract
   * @dev We check owner, admin, and identity for a more comprehensive coverage.
   * @return Returns true is message sender is an owner.
   */
  function isOwner() private view returns (bool) {
    return (msg.sender == getOwner() ||
      msg.sender == getAdmin() ||
      msg.sender == Owner(HolographerInterface(address(this)).getSourceContract()).owner());
  }

  /**
   * @dev This is here in place to prevent reverts in case contract is used outside of the protocol.
   */
  function getSourceContract() external view returns (address sourceContract) {
    sourceContract = address(this);
  }

  /**
   * @dev Gets the default royalty payment receiver address from storage slot.
   * @return receiver Wallet or smart contract that will receive the initial royalty payouts.
   */
  function _getDefaultReceiver() private view returns (address payable receiver) {
    assembly {
      receiver := sload(_defaultReceiverSlot)
    }
  }

  /**
   * @dev Sets the default royalty payment receiver address to storage slot.
   * @param receiver Wallet or smart contract that will receive the initial royalty payouts.
   */
  function _setDefaultReceiver(address receiver) private {
    assembly {
      sstore(_defaultReceiverSlot, receiver)
    }
  }

  /**
   * @dev Gets the default royalty base points(percentage) from storage slot.
   * @return bp Royalty base points(percentage) for royalty payouts.
   */
  function _getDefaultBp() private view returns (uint256 bp) {
    assembly {
      bp := sload(_defaultBpSlot)
    }
  }

  /**
   * @dev Sets the default royalty base points(percentage) to storage slot.
   * @param bp Uint256 of royalty percentage, provided in base points format.
   */
  function _setDefaultBp(uint256 bp) private {
    assembly {
      sstore(_defaultBpSlot, bp)
    }
  }

  /**
   * @dev Gets the royalty payment receiver address, for a particular token id, from storage slot.
   * @return receiver Wallet or smart contract that will receive the royalty payouts for a particular token id.
   */
  function _getReceiver(uint256 tokenId) private view returns (address payable receiver) {
    bytes32 slot = bytes32(uint256(keccak256(abi.encodePacked(_receiverString, tokenId))) - 1);
    assembly {
      receiver := sload(slot)
    }
  }

  /**
   * @dev Sets the royalty payment receiver address, for a particular token id, to storage slot.
   * @param tokenId Uint256 of the token id to set the receiver for.
   * @param receiver Wallet or smart contract that will receive the royalty payouts for a particular token id.
   */
  function _setReceiver(uint256 tokenId, address receiver) private {
    bytes32 slot = bytes32(uint256(keccak256(abi.encodePacked(_receiverString, tokenId))) - 1);
    assembly {
      sstore(slot, receiver)
    }
  }

  /**
   * @dev Gets the royalty base points(percentage), for a particular token id, from storage slot.
   * @return bp Royalty base points(percentage) for the royalty payouts of a specific token id.
   */
  function _getBp(uint256 tokenId) private view returns (uint256 bp) {
    bytes32 slot = bytes32(uint256(keccak256(abi.encodePacked(_bpString, tokenId))) - 1);
    assembly {
      bp := sload(slot)
    }
  }

  /**
   * @dev Sets the royalty base points(percentage), for a particular token id, to storage slot.
   * @param tokenId Uint256 of the token id to set the base points for.
   * @param bp Uint256 of royalty percentage, provided in base points format, for a particular token id.
   */
  function _setBp(uint256 tokenId, uint256 bp) private {
    bytes32 slot = bytes32(uint256(keccak256(abi.encodePacked(_bpString, tokenId))) - 1);
    assembly {
      sstore(slot, bp)
    }
  }

  function _getPayoutAddresses() private view returns (address payable[] memory addresses) {
    // The slot hash has been precomputed for gas optimizaion
    bytes32 slot = _payoutAddressesSlot;
    uint256 length;
    assembly {
      length := sload(slot)
    }
    addresses = new address payable[](length);
    address payable value;
    for (uint256 i = 0; i < length; i++) {
      slot = keccak256(abi.encodePacked(i, slot));
      assembly {
        value := sload(slot)
      }
      addresses[i] = value;
    }
  }

  function _setPayoutAddresses(address payable[] memory addresses) private {
    bytes32 slot = _payoutAddressesSlot;
    uint256 length = addresses.length;
    assembly {
      sstore(slot, length)
    }
    address payable value;
    for (uint256 i = 0; i < length; i++) {
      slot = keccak256(abi.encodePacked(i, slot));
      value = addresses[i];
      assembly {
        sstore(slot, value)
      }
    }
  }

  function _getPayoutBps() private view returns (uint256[] memory bps) {
    bytes32 slot = _payoutBpsSlot;
    uint256 length;
    assembly {
      length := sload(slot)
    }
    bps = new uint256[](length);
    uint256 value;
    for (uint256 i = 0; i < length; i++) {
      slot = keccak256(abi.encodePacked(i, slot));
      assembly {
        value := sload(slot)
      }
      bps[i] = value;
    }
  }

  function _setPayoutBps(uint256[] memory bps) private {
    bytes32 slot = _payoutBpsSlot;
    uint256 length = bps.length;
    assembly {
      sstore(slot, length)
    }
    uint256 value;
    for (uint256 i = 0; i < length; i++) {
      slot = keccak256(abi.encodePacked(i, slot));
      value = bps[i];
      assembly {
        sstore(slot, value)
      }
    }
  }

  function _getTokenAddress(string memory tokenName) private view returns (address tokenAddress) {
    bytes32 slot = bytes32(uint256(keccak256(abi.encodePacked(_tokenAddressString, tokenName))) - 1);
    assembly {
      tokenAddress := sload(slot)
    }
  }

  function _setTokenAddress(string memory tokenName, address tokenAddress) private {
    bytes32 slot = bytes32(uint256(keccak256(abi.encodePacked(_tokenAddressString, tokenName))) - 1);
    assembly {
      sstore(slot, tokenAddress)
    }
  }

  /**
   * @dev Private function that transfers ETH to all payout recipients.
   * @dev This contract is designed primarily to capture royalties, but is limited in payout logic.
   * @dev This function uses a push payment model, where the contract pushes the ETH to the recipients.
   * @dev The design is intended so that royalty distribution logic can be handled externally via payment distribution contracts.
   * @dev The recommended usage for royalty structures that require more complex payout logic to multiple recipients is to
   *      set 100% ownership payout with the recipient being the payment distribution contract.
   */
  function _payoutEth() private {
    address payable[] memory addresses = _getPayoutAddresses();
    uint256[] memory bps = _getPayoutBps();
    uint256 length = addresses.length;
    uint256 balance = address(this).balance;
    uint256 sending;
    bool extendedCall;
    assembly {
      extendedCall := sload(_extendedCallSlot)
    }
    for (uint256 i = 0; i < length; i++) {
      sending = ((bps[i] * balance) / 10000);
      // only send value if it is greater than 0
      if (sending > 0) {
        // If the contract enabled extended call on init then use call to transfer, otherwise use transfer
        if (extendedCall == true) {
          (bool success, ) = addresses[i].call{value: sending}("");
          require(success, "ROYALTIES: Transfer failed");
        } else {
          addresses[i].transfer(sending);
        }
      }
    }
  }

  /**
   * @dev Private function that transfers tokens to all payout recipients.
   * @dev ERC20 tokens that use fee on transfer are not supported.
   * @dev This contract is designed primarily to capture royalties, but is limited in payout logic.
   * @dev This function uses a push payment model, where the contract pushes the ETH to the recipients.
   * @dev The design is intended so that royalty distribution logic can be handled externally via payment distribution contracts.
   * @dev The recommended usage for royalty structures that require more complex payout logic to multiple recipients is to
   *      set 100% ownership payout with the recipient being the payment distribution contract.
   *
   * @param tokenAddress Smart contract address of ERC20 token.
   */
  function _payoutToken(address tokenAddress) private {
    address payable[] memory addresses = _getPayoutAddresses();
    uint256[] memory bps = _getPayoutBps();
    uint256 length = addresses.length;
    ERC20 erc20 = ERC20(tokenAddress);
    uint256 balance = erc20.balanceOf(address(this));
    uint256 sending;
    for (uint256 i = 0; i < length; i++) {
      sending = ((bps[i] * balance) / 10000);
      // Some tokens revert when transferring a zero value amount this check ensures if one recipient's
      // amount is zero, the transfer will still succeed for the other recipients.
      if (sending > 0) {
        require(
          _callOptionalReturn(
            tokenAddress,
            erc20.transfer.selector,
            abi.encode(address(addresses[i]), uint256(sending))
          ),
          "ROYALTIES: ERC20 transfer failed"
        );
      }
    }
  }

  /**
   * @dev Private function that transfers multiple tokens to all payout recipients.
   * @dev Try to use _payoutToken and handle each token individually.
   * @dev ERC20 tokens that use fee on transfer are not supported.
   * @dev This contract is designed primarily to capture royalties, but is limited in payout logic.
   * @dev This function uses a push payment model, where the contract pushes the ETH to the recipients.
   * @dev The design is intended so that royalty distribution logic can be handled externally via payment distribution contracts.
   * @dev The recommended usage for royalty structures that require more complex payout logic to multiple recipients is to
   *      set 100% ownership payout with the recipient being the payment distribution contract.
   *
   * @param tokenAddresses Array of smart contract addresses of ERC20 tokens.
   */
  function _payoutTokens(address[] memory tokenAddresses) private {
    address payable[] memory addresses = _getPayoutAddresses();
    uint256[] memory bps = _getPayoutBps();
    ERC20 erc20;
    uint256 balance;
    uint256 sending;
    for (uint256 t = 0; t < tokenAddresses.length; t++) {
      erc20 = ERC20(tokenAddresses[t]);
      balance = erc20.balanceOf(address(this));
      for (uint256 i = 0; i < addresses.length; i++) {
        sending = ((bps[i] * balance) / 10000);
        // Some tokens revert when transferring a zero value amount this check ensures if one recipient's
        // amount is zero, the transfer will still succeed for the other recipients.
        if (sending > 0) {
          require(
            _callOptionalReturn(
              tokenAddresses[t],
              erc20.transfer.selector,
              abi.encode(address(addresses[i]), uint256(sending))
            ),
            "ROYALTIES: ERC20 transfer failed"
          );
        }
      }
    }
  }

  /**
   * @dev This function validates that the call is being made by an authorised wallet.
   * @dev Will revert entire tranaction if it fails.
   */
  function _validatePayoutRequestor() private view {
    if (!isOwner()) {
      bool matched;
      address payable[] memory addresses = _getPayoutAddresses();
      address payable sender = payable(msg.sender);
      for (uint256 i = 0; i < addresses.length; i++) {
        if (addresses[i] == sender) {
          matched = true;
          break;
        }
      }
      require(matched, "ROYALTIES: sender not authorized");
    }
  }

  /**
   * @notice Set the wallets and percentages for royalty payouts.
   *         Limited to 10 wallets to prevent out of gas errors.
   *         For more complex royalty structures, set 100% ownership payout with the recipient being the payment distribution contract.
   * @dev Function can only we called by owner, admin, or identity wallet.
   * @dev Addresses and bps arrays must be equal length. Bps values added together must equal 10000 exactly.
   * @param addresses An array of all the addresses that will be receiving royalty payouts.
   * @param bps An array of the percentages that each address will receive from the royalty payouts.
   */
  function configurePayouts(address payable[] memory addresses, uint256[] memory bps) public onlyOwner {
    require(addresses.length == bps.length, "ROYALTIES: missmatched lenghts");
    require(addresses.length <= 10, "ROYALTIES: max 10 addresses");
    uint256 totalBp;
    for (uint256 i = 0; i < addresses.length; i++) {
      require(addresses[i] != address(0), "ROYALTIES: payee is zero address");
      require(bps[i] > 0, "ROYALTIES: bp is zero");
      totalBp = totalBp + bps[i];
    }
    require(totalBp == 10000, "ROYALTIES: bps must equal 10000");
    _setPayoutAddresses(addresses);
    _setPayoutBps(bps);
  }

  /**
   * @notice Show the wallets and percentages of payout recipients.
   * @dev These are the recipients that will be getting royalty payouts.
   * @return addresses An array of all the addresses that will be receiving royalty payouts.
   * @return bps An array of the percentages that each address will receive from the royalty payouts.
   */
  function getPayoutInfo() public view returns (address payable[] memory addresses, uint256[] memory bps) {
    addresses = _getPayoutAddresses();
    bps = _getPayoutBps();
  }

  /**
   * @notice Get payout of all ETH in smart contract.
   * @dev Distribute all the ETH(minus gas fees) to payout recipients.
   */
  function getEthPayout() public {
    _validatePayoutRequestor();
    _payoutEth();
  }

  /**
   * @notice Get payout for a specific token address. Token must have a positive balance!
   * @dev Contract owner, admin, identity wallet, and payout recipients can call this function.
   * @param tokenAddress An address of the token for which to issue payouts for.
   */
  function getTokenPayout(address tokenAddress) public {
    _validatePayoutRequestor();
    _payoutToken(tokenAddress);
  }

  /**
   * @notice Get payouts for tokens listed by address. Tokens must have a positive balance!
   * @dev Each token balance must be equal or greater than 10000. Otherwise calculating BP is difficult.
   * @param tokenAddresses An address array of tokens to issue payouts for.
   */
  function getTokensPayout(address[] memory tokenAddresses) public {
    _validatePayoutRequestor();
    _payoutTokens(tokenAddresses);
  }

  /**
   * @notice Set the royalty information for entire contract, or a specific token.
   * @dev Take great care to not make this function accessible by other public functions in your overlying smart contract.
   * @param tokenId Set a specific token id, or leave at 0 to set as default parameters.
   * @param receiver Wallet or smart contract that will receive the royalty payouts.
   * @param bp Uint256 of royalty percentage, provided in base points format.
   */
  function setRoyalties(uint256 tokenId, address payable receiver, uint256 bp) public onlyOwner {
    require(receiver != address(0), "ROYALTIES: receiver is zero address");
    require(bp <= 10000, "ROYALTIES: base points over 100%");
    if (tokenId == 0) {
      _setDefaultReceiver(receiver);
      _setDefaultBp(bp);
    } else {
      _setReceiver(tokenId, receiver);
      _setBp(tokenId, bp);
    }
    address[] memory receivers = new address[](1);
    receivers[0] = address(receiver);
    uint256[] memory bps = new uint256[](1);
    bps[0] = bp;
    emit SecondarySaleFees(tokenId, receivers, bps);
  }

  // IEIP2981
  function royaltyInfo(uint256 tokenId, uint256 value) public view returns (address, uint256) {
    if (_getReceiver(tokenId) == address(0)) {
      return (_getDefaultReceiver(), (_getDefaultBp() * value) / 10000);
    } else {
      return (_getReceiver(tokenId), (_getBp(tokenId) * value) / 10000);
    }
  }

  // Rarible V1
  function getFeeBps(uint256 tokenId) public view returns (uint256[] memory) {
    uint256[] memory bps = new uint256[](1);
    if (_getReceiver(tokenId) == address(0)) {
      bps[0] = _getDefaultBp();
    } else {
      bps[0] = _getBp(tokenId);
    }
    return bps;
  }

  // Rarible V1
  function getFeeRecipients(uint256 tokenId) public view returns (address payable[] memory) {
    address payable[] memory receivers = new address payable[](1);
    if (_getReceiver(tokenId) == address(0)) {
      receivers[0] = _getDefaultReceiver();
    } else {
      receivers[0] = _getReceiver(tokenId);
    }
    return receivers;
  }

  // Rarible V2(not being used since it creates a conflict with Manifold royalties)
  // struct Part {
  //     address payable account;
  //     uint96 value;
  // }

  // function getRoyalties(uint256 tokenId) public view returns (Part[] memory) {
  //     return royalties[id];
  // }

  // Manifold
  function getRoyalties(uint256 tokenId) public view returns (address payable[] memory, uint256[] memory) {
    address payable[] memory receivers = new address payable[](1);
    uint256[] memory bps = new uint256[](1);
    if (_getReceiver(tokenId) == address(0)) {
      receivers[0] = _getDefaultReceiver();
      bps[0] = _getDefaultBp();
    } else {
      receivers[0] = _getReceiver(tokenId);
      bps[0] = _getBp(tokenId);
    }
    return (receivers, bps);
  }

  // Foundation
  function getFees(uint256 tokenId) public view returns (address payable[] memory, uint256[] memory) {
    address payable[] memory receivers = new address payable[](1);
    uint256[] memory bps = new uint256[](1);
    if (_getReceiver(tokenId) == address(0)) {
      receivers[0] = _getDefaultReceiver();
      bps[0] = _getDefaultBp();
    } else {
      receivers[0] = _getReceiver(tokenId);
      bps[0] = _getBp(tokenId);
    }
    return (receivers, bps);
  }

  // SuperRare
  // Hint taken from Manifold's RoyaltyEngine(https://github.com/manifoldxyz/royalty-registry-solidity/blob/main/contracts/RoyaltyEngineV1.sol)
  // To be quite honest, SuperRare is a closed marketplace. They're working on opening it up but looks like they want to use private smart contracts.
  // We'll just leave this here for just in case they open the flood gates.
  function tokenCreator(
    address,
    /* contractAddress*/
    uint256 tokenId
  ) public view returns (address) {
    address receiver = _getReceiver(tokenId);
    if (receiver == address(0)) {
      return _getDefaultReceiver();
    }
    return receiver;
  }

  // SuperRare
  function calculateRoyaltyFee(
    address,
    /* contractAddress */
    uint256 tokenId,
    uint256 amount
  ) public view returns (uint256) {
    if (_getReceiver(tokenId) == address(0)) {
      return (_getDefaultBp() * amount) / 10000;
    } else {
      return (_getBp(tokenId) * amount) / 10000;
    }
  }

  // Holograph
  // we indicate that this contract operates market functions
  function marketContract() public view returns (address) {
    return address(this);
  }

  // Holograph
  // we indicate that the receiver is the creator, to convince the smart contract to pay
  function tokenCreators(uint256 tokenId) public view returns (address) {
    address receiver = _getReceiver(tokenId);
    if (receiver == address(0)) {
      return _getDefaultReceiver();
    }
    return receiver;
  }

  // Holograph
  // we provide the percentage that needs to be paid out from the sale
  function bidSharesForToken(uint256 tokenId) public view returns (HolographBidShares memory bidShares) {
    // this information is outside of the scope of our
    bidShares.prevOwner.value = 0;
    bidShares.owner.value = 0;
    if (_getReceiver(tokenId) == address(0)) {
      bidShares.creator.value = _getDefaultBp() * (10 ** 16);
    } else {
      bidShares.creator.value = _getBp(tokenId) * (10 ** 16);
    }
    return bidShares;
  }

  /**
   * @notice Get the smart contract address of a token by common name.
   * @dev Used only to identify really major/common tokens. Avoid using due to gas usages.
   * @param tokenName The ticker symbol of the token. For example "USDC" or "DAI".
   * @return The smart contract address of the token ticker symbol. Or zero address if not found.
   */
  function getTokenAddress(string memory tokenName) public view returns (address) {
    return _getTokenAddress(tokenName);
  }

  /**
   * @notice Used to wrap function calls to check if they return without revert regardless of return type.
   * @dev Checks if wrapped function opcode is a revert, if it is then it reverts as well, if it's not then
   *      it checks for return data, if return data exists, it is returned as a bool,
   *      if return data does not exist (0 length) then success is expected and returns true
   * @return Returns true if the wrapped function call returns without a revert even if it doesn't return true.
   */
  function _callOptionalReturn(address target, bytes4 functionSignature, bytes memory payload) internal returns (bool) {
    bytes memory data = abi.encodePacked(functionSignature, payload);
    bool success = true;
    assembly {
      let result := call(gas(), target, callvalue(), add(data, 0x20), mload(data), 0, 0)
      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        if gt(returndatasize(), 0) {
          returndatacopy(success, 0, 0x20)
        }
      }
    }
    return success;
  }
}
