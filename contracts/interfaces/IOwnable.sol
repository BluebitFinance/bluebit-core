// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

interface IOwnable {
    function owner() external returns (address);

    function manager() external returns (address);

    event OwnerChanged(address indexed previousValue, address indexed newValue);
    event ManagerChanged(address indexed previousValue, address indexed newValue);
}
