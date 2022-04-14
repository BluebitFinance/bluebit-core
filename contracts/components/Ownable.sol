// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import '../interfaces/IOwnable.sol';

abstract contract Ownable is IOwnable {
    address public override owner;
    address public override manager;

    constructor() internal {
        owner = msg.sender;
        manager = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Ownable: caller is not the owner');
        _;
    }

    modifier onlyManager() {
        require(msg.sender == manager, 'Ownable: caller is not the manager');
        _;
    }

    modifier allManager() {
        require(msg.sender == manager || msg.sender == owner, 'Ownable: caller is not the manager or the owner');
        _;
    }

    function setOwner(address _owner) external onlyOwner {
        require(_owner != address(0), 'Ownable: new owner is the zero address');
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    function setManager(address _manager) external onlyOwner {
        require(_manager != address(0), 'Ownable: new manager is the zero address');
        emit ManagerChanged(manager, _manager);
        manager = _manager;
    }
}
