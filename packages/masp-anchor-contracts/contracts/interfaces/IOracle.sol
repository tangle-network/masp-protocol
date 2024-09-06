// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IOracle {
    function getPriceAndBalance(address, address) external view returns (uint256, uint256);
    function getPrice(address) external view returns (uint256);
}