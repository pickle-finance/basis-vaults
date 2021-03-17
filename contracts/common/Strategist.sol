// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;
import "./Context.sol";
contract Strategist is Context {
    address private _strategist;

    event StrategistTransferred(address indexed previousStrategist, address indexed newStrategist);

    constructor () {
        address msgSender = _msgSender();
        _strategist = msgSender;
        emit StrategistTransferred(address(0), msgSender);
    }

    function strategist() public view returns (address) {
        return _strategist;
    }

    modifier onlyStrategist() {
        require(_strategist == _msgSender(), "Strategist: caller is not the strategist");
        _;
    }

    function transferStrategist(address newStrategist) public virtual onlyStrategist {
        require(newStrategist != address(0), "Strategist: new strategist is the zero address");
        emit StrategistTransferred(_strategist, newStrategist);
        _strategist = newStrategist;
    }
}
