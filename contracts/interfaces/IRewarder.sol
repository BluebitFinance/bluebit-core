// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './IERC20.sol';

interface IRewarder {
    function onReward(address user, uint256 lpAmount) external;

    function pendingRewards(address user) external view returns (IERC20[] memory, uint256[] memory);
}
