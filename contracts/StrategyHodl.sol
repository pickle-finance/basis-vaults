// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "./common/Ownable.sol";
import "./common/Address.sol";
import "./common/SafeERC20.sol";
import "./interfaces/IStrategy.sol";

contract StrategyHodl is IStrategy, Ownable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public token;

    constructor(address _token) {
        token = _token;
    }

    function convertDepositedIntoEarnable() public override {
    }
    function convertEarnableIntoDeposited() public override {
    }
    
    function want() public view override returns (address) {
        return token;
    }
    function deposit() public override {
    }
    function withdraw(uint256 _amount) public override {
        IERC20(token).safeTransfer(msg.sender, _amount);
    }
    function balanceOf() public view override returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    function balanceOfYieldToken() public pure override returns (uint256) {
        return 0;
    }
    function harvest() public override {
    }
    function withdrawAll() public override {
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(msg.sender, tokenBalance);
    }
}
