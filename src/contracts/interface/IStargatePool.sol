// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStargatePool {
    function token() external view returns (address);
    function lpToken() external view returns (address);
    function deposit(address receiver, uint256 amount) external returns (uint256);
    function redeem(uint256 amount, address receiver) external returns (uint256);
    function sharedDecimals() external view returns (uint8);
}
