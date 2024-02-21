// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./VERC20.sol";
import "../interface/IVault.sol";
import "../utils/Role.sol";


contract VToken is VERC20, IVault, Role {
    using SafeMath for uint;
    uint accrualBlockNumber;
    mapping(address => uint) userStakingAmount;

    address correspond;
    IERC20 correspondToken;

    function initialize(
        address correspond_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_) external {
        correspond = correspond_;
        correspondToken = IERC20(correspond);
        init(name_, symbol_, decimals_);
    }

    function correspondBalance() public view returns (uint){
        return IERC20(correspond).balanceOf(address(this));
    }

    function getCTokenQuantity(uint amount) public view returns (uint){
        if (totalSupply() == 0){
            return amount;
        }
        uint allCorrespond = correspondBalance();
        uint allCToken = totalSupply();
        return amount.mul(allCToken).div(allCorrespond);
    }

    function getCorrespondQuantity(uint amount) public view returns (uint){
        uint allCorrespond = correspondBalance();
        uint allCToken = totalSupply();
        return amount.mul(allCorrespond).div(allCToken);
    }

    function staking(uint amount) external override {
        uint ctoken = getCTokenQuantity(amount);
        correspondToken.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, ctoken);
    }

    function stakingTo(uint amount, address to) external override onlyManager {
        uint ctoken = getCTokenQuantity(amount);
        _mint(to, ctoken);
    }

    function withdraw(uint amount) external override {
        uint correspondAmount = getCorrespondQuantity(amount);
        _burn(msg.sender, amount);
        correspondToken.transfer(msg.sender, correspondAmount);
    }
}