pragma solidity 0.5.16;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./StreamGoldRoot.sol";


// Smart Contract regulating the total supply of gold locked at any
// given time so that the Stream Gold contract can't over mint Stream tokens
contract LockedGoldOracle is Ownable {

  using SafeMath for uint256;

  uint256 private _lockedGold;
  address private _streamContract;

  event LockEvent(uint256 amount);
  event UnlockEvent(uint256 amount);

  function setSteamContract(address streamContract) external onlyOwner {
    _streamContract = streamContract;
  }

  function lockAmount(uint256 amountGrams) external onlyOwner {
    _lockedGold = _lockedGold.add(amountGrams);
    emit LockEvent(amountGrams);
  }

  // Can only unlock amount of gold if it would leave the
  // total amount of locked gold greater than or equal to the
  // number of tokens in circulation
  function unlockAmount(uint256 amountGrams) external onlyOwner {
    _lockedGold = _lockedGold.sub(amountGrams);
    require(_lockedGold >= StreamGold(_streamContract).totalCirculation());
    emit UnlockEvent(amountGrams);
  }

  function lockedGold() external view returns(uint256) {
    return _lockedGold;
  }

  function streamContract() external view returns(address) {
    return _streamContract;
  }
}