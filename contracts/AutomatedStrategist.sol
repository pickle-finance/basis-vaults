// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "./common/Ownable.sol";
import "./common/Address.sol";
import "./common/SafeERC20.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IAutomatedSeigniorageStrategist.sol";

contract AutomatedStrategist is IAutomatedSeigniorageStrategist, Ownable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    uint256 abovePegThreshold;
    uint256 belowPegThreshold;
    
    address vault;
    IOracle oracle;
    IStrategy abovePeg;
    IStrategy onPeg;
    IStrategy belowPeg;
    IStrategy noRisk;
    
    bool panicMode;    
    bool configured;
    
    constructor() {
    }
    
    function configure(address _vault, 
                       address _oracle,
                       address _abovePegStrategy,
                       address _onPegStrategy,
                       address _belowPegStrategy,
                       address _noRiskStrategy,
                       uint256 _abovePegThreshold,
                       uint256 _belowPegThreshold) public override onlyOwner {
        abovePegThreshold = _abovePegThreshold;
        belowPegThreshold = _belowPegThreshold;
        vault = _vault;
         oracle = IOracle(_oracle);
        abovePeg = IStrategy(_abovePegStrategy);
        onPeg = IStrategy(_onPegStrategy);
        belowPeg = IStrategy(_belowPegStrategy);
        configured = true;
    }

    modifier isConfigured() {
        require(configured, 'AutomatedStrategist not yet configured!');
        _;
    }
    
    modifier onlyVault() {
        require(msg.sender == vault, "Only vault may choose strategy");
        _;
    }
    
    function chooseStrategy() public override isConfigured() onlyVault() returns (address) {
        if (panicMode) {
           return address(noRisk);
        }
        
        uint256 price = oracle.price();
        if (price > abovePegThreshold) {
           return address(abovePeg);
        }
        if (price < belowPegThreshold) {
           return address(belowPeg);
        }
        return address(onPeg);
    }
    
    function panic() public override onlyVault() {
        panicMode = true;
    }
    
    function calmDown()  public override onlyVault() {
        panicMode = false;
    }
    
}
