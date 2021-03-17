// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "../common/SafeMath.sol";
import "../common/SafeERC20.sol";
import "../interfaces/IMasterChef.sol";

contract MockMasterChef is IMasterChef {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    address public token;
    address public yieldtoken;
    mapping(address => uint) balances;
    
    constructor(address _token, address _yieldtoken) {
       token = _token;
       yieldtoken = _yieldtoken;
    }

    function deposit(uint256 _pid, uint256 _amount) public override {
    
    }

    function withdraw(uint256 _pid, uint256 _amount) public override {
    
    }

    function enterStaking(uint256 _amount) public override {
        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
        balances[msg.sender] = balances[msg.sender].add(_amount);
    }

    function leaveStaking(uint256 _amount) public override {
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        IERC20(token).safeTransfer(msg.sender, _amount);
        IERC20(yieldtoken).safeTransfer(msg.sender, 100);
    }

    function pending(uint256 _pid, address _user) public override view returns (uint256) {
        return 100;
    }

    function userInfo(uint256 _pid, address _user) public override view returns (uint256, uint256) {
        return (balances[msg.sender], 0);
    }

    function emergencyWithdraw(uint256 _pid) public override {
    
    }
}