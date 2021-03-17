// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;
import "./SafeMath.sol";
import "./Address.sol";
import "./Ownable.sol";
import "./ERC20.sol";

contract MintableERC20 is ERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    constructor (string memory name, string memory symbol) ERC20(name, symbol) {
    }

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }
}
