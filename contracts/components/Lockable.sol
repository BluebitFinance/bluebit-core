// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

abstract contract Lockable {
    bool public locked;

    constructor() internal {
        locked = false;
    }

    modifier notLocked() {
        require(!locked, 'Lockable: locked');

        locked = true;
        _;
        locked = false;
    }
}
