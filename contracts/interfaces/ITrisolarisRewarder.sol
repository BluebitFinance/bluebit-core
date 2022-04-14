// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './IERC20.sol';

interface ITrisolarisRewarder {
    function tokenPerBlock() external view returns (uint256);

    function setRewardRate(uint256 _tokenPerBlock) external;

    function pendingTokens(
        uint256 pid,
        address user,
        uint256 triAmount
    ) external view returns (IERC20[] memory, uint256[] memory);
}
