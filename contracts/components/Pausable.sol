// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './Ownable.sol';

abstract contract Pausable is Ownable {
    bool public paused;

    event PauseChanged(bool indexed previousValue, bool indexed newValue);

    modifier notPaused() {
        require(!paused, 'Pausable: paused');
        _;
    }

    constructor() internal {
        paused = false;
    }

    function setPaused(bool _paused) external onlyOwner {
        if (paused == _paused) return;
        emit PauseChanged(paused, _paused);
        paused = _paused;
    }
}
