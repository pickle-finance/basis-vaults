// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;
import "./IAutomatedStrategist.sol";

interface IAutomatedSeigniorageStrategist is IAutomatedStrategist {
    function configure(address vault, address oracle, address abovePegStrategy, address onPegStrategy, address belowPegStrategy, address noRiskStrategy, uint256 _abovePegThreshold, uint256 _belowPegThreshold) external;
}
