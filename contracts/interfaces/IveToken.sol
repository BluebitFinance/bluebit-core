// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './IERC20.sol';

interface IveToken is IERC20 {
    struct Lock {
        uint256 amount;
        uint256 unlockTime;
    }

    struct Point {
        uint256 slope;
        uint256 bias;
    }

    function increaseAmount(uint256 amount) external;

    function increaseTime(uint256 unlockTime) external;

    function lock(uint256 amount, uint256 unlockTime) external;

    function unlock() external;

    function lockedOf(address account) external view returns (uint256 amount, uint256 unlockTime);

    function totalLocked() external view returns (uint256);

    function rate(address account) external view returns (uint256);

    function rateAt(address account, uint256 timestamp) external view returns (uint256);

    event Locked(address indexed account, uint256 amount, uint256 unlockTime);
    event Unlocked(address indexed account, uint256 amount);
}
