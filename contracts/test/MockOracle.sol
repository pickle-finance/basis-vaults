// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "../common/SafeMath.sol";
import "../interfaces/IOracle.sol";

contract MockOracle is IOracle {
    using SafeMath for uint256;
    
    uint256 oraclePrice;
    
    constructor() {
    }

    function setPrice(uint256 _price) public {
        oraclePrice = _price;
    }

    function price() public view override returns (uint256) {
        return oraclePrice;
    }
}