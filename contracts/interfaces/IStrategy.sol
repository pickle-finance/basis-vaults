// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;
interface IStrategy {
    function convertDepositedIntoEarnable() external;
    function convertEarnableIntoDeposited() external;
    function want() external view returns (address);
    function deposit() external;
    function withdraw(uint256) external;
    function withdrawAll() external;
    function balanceOf() external view returns (uint256);
    function balanceOfYieldToken() external view returns (uint256);
    function harvest() external;
}
