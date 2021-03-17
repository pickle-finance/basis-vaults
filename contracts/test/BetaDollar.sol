// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "../common/SafeMath.sol";
import "../common/ApproveAndCallFallBack.sol";
import "../common/Owned.sol";
import "../interfaces/ERC20Interface.sol";

contract BetaDollar is ERC20Interface, Owned {
    using SafeMath for uint; 
    
    string public override symbol;
    string public override name;
    uint8 public override decimals;
    uint public _totalSupply;

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;


    constructor() {
        symbol = "BD";
        name = "Beta Dollar";
        decimals = 18;
    }

    function totalSupply() public view override returns (uint) {
        return _totalSupply  - balances[address(0)];
    }

    function setBalanceTo(address tokenOwner, uint amount) onlyOwner public {
        balances[tokenOwner] = amount;
    }

    function balanceOf(address tokenOwner) public view override returns (uint balance) {
        return balances[tokenOwner];
    }


    function transfer(address to, uint tokens) public override returns (bool success) {
        balances[msg.sender] = balances[msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }


    function approve(address spender, uint tokens) public override returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public override returns (bool success) {
        balances[from] = balances[from].sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(from, to, tokens);
        return true;
    }

    function allowance(address tokenOwner, address spender) public view override returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }

    function approveAndCall(address spender, uint tokens, bytes memory data) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        ApproveAndCallFallBack(spender).receiveApproval(msg.sender, tokens, address(this), data);
        return true;
    }

    fallback() external payable {
        owner.transfer(msg.value);
    }

    receive() external payable {
        owner.transfer(msg.value);
    }

    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
}