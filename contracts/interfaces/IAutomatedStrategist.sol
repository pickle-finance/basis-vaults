// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;
interface IAutomatedStrategist {
    function chooseStrategy() external returns (address);

    function panic() external;
    function calmDown() external;
}
