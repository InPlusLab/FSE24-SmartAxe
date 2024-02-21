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

import "../abstract/EIP712.sol";
import "../abstract/NonReentrant.sol";

import "../interface/ERC20.sol";
import "../interface/ERC20Burnable.sol";
import "../interface/HolographERC20Interface.sol";
import "../interface/ERC20Metadata.sol";
import "../interface/ERC20Permit.sol";
import "../interface/ERC20Receiver.sol";
import "../interface/ERC20Safer.sol";
import "../interface/ERC165.sol";
import "../interface/ERC165.sol";

import "../library/ECDSA.sol";

/**
 * @title Mock ERC20 Token
 * @author Holograph Foundation
 * @notice Used for imitating the likes of WETH and WMATIC tokens.
 * @dev The entire logic and functionality of the smart contract is self-contained.
 */
contract ERC20Mock is
  ERC165,
  ERC20,
  ERC20Burnable,
  ERC20Metadata,
  ERC20Receiver,
  ERC20Safer,
  ERC20Permit,
  NonReentrant,
  EIP712
{
  bool private _works;

  /**
   * @dev Mapping of all the addresse's balances.
   */
  mapping(address => uint256) private _balances;

  /**
   * @dev Mapping of all authorized operators, and capped amounts.
   */
  mapping(address => mapping(address => uint256)) private _allowances;

  /**
   * @dev Total number of token in circulation.
   */
  uint256 private _totalSupply;

  /**
   * @dev Token name.
   */
  string private _name;

  /**
   * @dev Token ticker symbol.
   */
  string private _symbol;

  /**
   * @dev Token number of decimal places.
   */
  uint8 private _decimals;

  /**
   * @dev List of all supported ERC165 interfaces.
   */
  mapping(bytes4 => bool) private _supportedInterfaces;

  /**
   * @dev List of used up nonces. Used in the ERC20Permit interface functionality.
   */
  mapping(address => uint256) private _nonces;

  /**
   * @dev Constructor does not accept any parameters.
   */
  constructor(
    string memory contractName,
    string memory contractSymbol,
    uint8 contractDecimals,
    string memory domainSeperator,
    string memory domainVersion
  ) {
    _works = true;
    _name = contractName;
    _symbol = contractSymbol;
    _decimals = contractDecimals;

    // ERC165
    _supportedInterfaces[ERC165.supportsInterface.selector] = true;

    // ERC20
    _supportedInterfaces[ERC20.allowance.selector] = true;
    _supportedInterfaces[ERC20.approve.selector] = true;
    _supportedInterfaces[ERC20.balanceOf.selector] = true;
    _supportedInterfaces[ERC20.totalSupply.selector] = true;
    _supportedInterfaces[ERC20.transfer.selector] = true;
    _supportedInterfaces[ERC20.transferFrom.selector] = true;
    _supportedInterfaces[
      ERC20.allowance.selector ^
        ERC20.approve.selector ^
        ERC20.balanceOf.selector ^
        ERC20.totalSupply.selector ^
        ERC20.transfer.selector ^
        ERC20.transferFrom.selector
    ] = true;

    // ERC20Metadata
    _supportedInterfaces[ERC20Metadata.name.selector] = true;
    _supportedInterfaces[ERC20Metadata.symbol.selector] = true;
    _supportedInterfaces[ERC20Metadata.decimals.selector] = true;
    _supportedInterfaces[
      ERC20Metadata.name.selector ^ ERC20Metadata.symbol.selector ^ ERC20Metadata.decimals.selector
    ] = true;

    // ERC20Burnable
    _supportedInterfaces[ERC20Burnable.burn.selector] = true;
    _supportedInterfaces[ERC20Burnable.burnFrom.selector] = true;
    _supportedInterfaces[ERC20Burnable.burn.selector ^ ERC20Burnable.burnFrom.selector] = true;

    // ERC20Safer
    // bytes4(keccak256(abi.encodePacked('safeTransfer(address,uint256)'))) == 0x423f6cef
    _supportedInterfaces[0x423f6cef] = true;
    // bytes4(keccak256(abi.encodePacked('safeTransfer(address,uint256,bytes)'))) == 0xeb795549
    _supportedInterfaces[0xeb795549] = true;
    // bytes4(keccak256(abi.encodePacked('safeTransferFrom(address,address,uint256)'))) == 0x42842e0e
    _supportedInterfaces[0x42842e0e] = true;
    // bytes4(keccak256(abi.encodePacked('safeTransferFrom(address,address,uint256,bytes)'))) == 0xb88d4fde
    _supportedInterfaces[0xb88d4fde] = true;
    _supportedInterfaces[bytes4(0x423f6cef) ^ bytes4(0xeb795549) ^ bytes4(0x42842e0e) ^ bytes4(0xb88d4fde)] = true;

    // ERC20Receiver
    _supportedInterfaces[ERC20Receiver.onERC20Received.selector] = true;

    // ERC20Permit
    _supportedInterfaces[ERC20Permit.permit.selector] = true;
    _supportedInterfaces[ERC20Permit.nonces.selector] = true;
    _supportedInterfaces[ERC20Permit.DOMAIN_SEPARATOR.selector] = true;
    _supportedInterfaces[
      ERC20Permit.permit.selector ^ ERC20Permit.nonces.selector ^ ERC20Permit.DOMAIN_SEPARATOR.selector
    ] = true;
    _eip712_init(domainSeperator, domainVersion);
  }

  function toggleWorks(bool active) external {
    _works = active;
  }

  function transferTokens(address payable token, address to, uint256 amount) external {
    ERC20(token).transfer(to, amount);
  }

  /**
   * @dev Purposefully left empty, to prevent running out of gas errors when receiving native token payments.
   */
  receive() external payable {}

  function decimals() public view returns (uint8) {
    return _decimals;
  }

  /**
   * @dev Although EIP-165 is not required for ERC20 contracts, we still decided to implement it.
   *
   * This makes it easier for external smart contracts to easily identify a valid ERC20 token contract.
   */
  function supportsInterface(bytes4 interfaceId) public view returns (bool) {
    return _supportedInterfaces[interfaceId];
  }

  function allowance(address account, address spender) public view returns (uint256) {
    return _allowances[account][spender];
  }

  function balanceOf(address account) public view returns (uint256) {
    return _balances[account];
  }

  // solhint-disable-next-line func-name-mixedcase
  function DOMAIN_SEPARATOR() public view returns (bytes32) {
    return _domainSeparatorV4();
  }

  function name() public view returns (string memory) {
    return _name;
  }

  function nonces(address account) public view returns (uint256) {
    return _nonces[account];
  }

  function symbol() public view returns (string memory) {
    return _symbol;
  }

  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  function approve(address spender, uint256 amount) public returns (bool) {
    _approve(msg.sender, spender, amount);
    return true;
  }

  function burn(uint256 amount) public {
    _burn(msg.sender, amount);
  }

  function burnFrom(address account, uint256 amount) public returns (bool) {
    uint256 currentAllowance = _allowances[account][msg.sender];
    require(currentAllowance >= amount, "ERC20: amount exceeds allowance");
    unchecked {
      _allowances[account][msg.sender] = currentAllowance - amount;
    }
    _burn(account, amount);
    return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
    uint256 currentAllowance = _allowances[msg.sender][spender];
    require(currentAllowance >= subtractedValue, "ERC20: decreased below zero");
    uint256 newAllowance;
    unchecked {
      newAllowance = currentAllowance - subtractedValue;
    }
    _approve(msg.sender, spender, newAllowance);
    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
    uint256 currentAllowance = _allowances[msg.sender][spender];
    uint256 newAllowance;
    unchecked {
      newAllowance = currentAllowance + addedValue;
    }
    unchecked {
      require(newAllowance >= currentAllowance, "ERC20: increased above max value");
    }
    _approve(msg.sender, spender, newAllowance);
    return true;
  }

  function mint(address account, uint256 amount) external {
    _mint(account, amount);
  }

  function onERC20Received(
    address account,
    address /* sender*/,
    uint256 amount,
    bytes calldata /* data*/
  ) public returns (bytes4) {
    assembly {
      // used to drop "change function to view" compiler warning
      sstore(0x17fb676f92438402d8ef92193dd096c59ee1f4ba1bb57f67f3e6d2eef8aeed5e, amount)
    }
    if (_works) {
      require(_isContract(account), "ERC20: operator not contract");
      try ERC20(account).balanceOf(address(this)) returns (uint256 balance) {
        require(balance >= amount, "ERC20: balance check failed");
      } catch {
        revert("ERC20: failed getting balance");
      }
      return ERC20Receiver.onERC20Received.selector;
    } else {
      return 0x00000000;
    }
  }

  function permit(
    address account,
    address spender,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public {
    require(block.timestamp <= deadline, "ERC20: expired deadline");
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    //  == 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9
    bytes32 structHash = keccak256(
      abi.encode(
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9,
        account,
        spender,
        amount,
        _useNonce(account),
        deadline
      )
    );
    bytes32 hash = _hashTypedDataV4(structHash);
    address signer = ECDSA.recover(hash, v, r, s);
    require(signer == account, "ERC20: invalid signature");
    _approve(account, spender, amount);
  }

  function safeTransfer(address recipient, uint256 amount) public returns (bool) {
    return safeTransfer(recipient, amount, "");
  }

  function safeTransfer(address recipient, uint256 amount, bytes memory data) public returns (bool) {
    _transfer(msg.sender, recipient, amount);
    require(_checkOnERC20Received(msg.sender, recipient, amount, data), "ERC20: non ERC20Receiver");
    return true;
  }

  function safeTransferFrom(address account, address recipient, uint256 amount) public returns (bool) {
    return safeTransferFrom(account, recipient, amount, "");
  }

  function safeTransferFrom(
    address account,
    address recipient,
    uint256 amount,
    bytes memory data
  ) public returns (bool) {
    if (account != msg.sender) {
      uint256 currentAllowance = _allowances[account][msg.sender];
      require(currentAllowance >= amount, "ERC20: amount exceeds allowance");
      unchecked {
        _allowances[account][msg.sender] = currentAllowance - amount;
      }
    }
    _transfer(account, recipient, amount);
    require(_checkOnERC20Received(account, recipient, amount, data), "ERC20: non ERC20Receiver");
    return true;
  }

  function transfer(address recipient, uint256 amount) public returns (bool) {
    _transfer(msg.sender, recipient, amount);
    return true;
  }

  function transferFrom(address account, address recipient, uint256 amount) public returns (bool) {
    if (account != msg.sender) {
      uint256 currentAllowance = _allowances[account][msg.sender];
      require(currentAllowance >= amount, "ERC20: amount exceeds allowance");
      unchecked {
        _allowances[account][msg.sender] = currentAllowance - amount;
      }
    }
    _transfer(account, recipient, amount);
    return true;
  }

  function _approve(address account, address spender, uint256 amount) internal {
    require(account != address(0), "ERC20: account is zero address");
    require(spender != address(0), "ERC20: spender is zero address");
    _allowances[account][spender] = amount;
    emit Approval(account, spender, amount);
  }

  function _burn(address account, uint256 amount) internal {
    require(account != address(0), "ERC20: account is zero address");
    uint256 accountBalance = _balances[account];
    require(accountBalance >= amount, "ERC20: amount exceeds balance");
    unchecked {
      _balances[account] = accountBalance - amount;
    }
    _totalSupply -= amount;
    emit Transfer(account, address(0), amount);
  }

  function _checkOnERC20Received(
    address account,
    address recipient,
    uint256 amount,
    bytes memory data
  ) internal nonReentrant returns (bool) {
    if (_isContract(recipient)) {
      try ERC165(recipient).supportsInterface(0x01ffc9a7) returns (bool erc165support) {
        require(erc165support, "ERC20: no ERC165 support");
        // we have erc165 support
        if (ERC165(recipient).supportsInterface(0x534f5876)) {
          // we have eip-4524 support
          try ERC20Receiver(recipient).onERC20Received(msg.sender, account, amount, data) returns (bytes4 retval) {
            return retval == ERC20Receiver.onERC20Received.selector;
          } catch (bytes memory reason) {
            if (reason.length == 0) {
              revert("ERC20: non ERC20Receiver");
            } else {
              assembly {
                revert(add(32, reason), mload(reason))
              }
            }
          }
        } else {
          revert("ERC20: eip-4524 not supported");
        }
      } catch (bytes memory reason) {
        if (reason.length == 0) {
          revert("ERC20: no ERC165 support");
        } else {
          assembly {
            revert(add(32, reason), mload(reason))
          }
        }
      }
    } else {
      return true;
    }
  }

  /**
   * @notice Mints tokens.
   * @dev Mint a specific amount of tokens to a specific address.
   * @param to Address to mint to.
   * @param amount Amount of tokens to mint.
   */
  function _mint(address to, uint256 amount) internal {
    require(to != address(0), "ERC20: minting to burn address");
    _totalSupply += amount;
    _balances[to] += amount;
    emit Transfer(address(0), to, amount);
  }

  function _transfer(address account, address recipient, uint256 amount) internal {
    require(account != address(0), "ERC20: account is zero address");
    require(recipient != address(0), "ERC20: recipient is zero address");
    uint256 accountBalance = _balances[account];
    require(accountBalance >= amount, "ERC20: amount exceeds balance");
    unchecked {
      _balances[account] = accountBalance - amount;
    }
    _balances[recipient] += amount;
    emit Transfer(account, recipient, amount);
  }

  /**
   * @dev "Consume a nonce": return the current value and increment.
   *
   * _Available since v4.1._
   */
  function _useNonce(address account) internal returns (uint256 current) {
    current = _nonces[account];
    _nonces[account]++;
  }

  function _isContract(address contractAddress) private view returns (bool) {
    bytes32 codehash;
    assembly {
      codehash := extcodehash(contractAddress)
    }
    return (codehash != 0x0 && codehash != 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470);
  }
}
