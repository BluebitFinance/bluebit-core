// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './IERC20.sol';

interface IRebatePool {
    function token0() external view returns (IERC20);

    function token1() external view returns (IERC20);

    function lastdays(uint256 _days) external view returns (uint256 token0Amount, uint256 token1Amount);

    function depositsAt(uint256 timestamp) external view returns (uint256 token0Amount, uint256 token1Amount);

    function veRateAt(address account, uint256 timestamp) external view returns (uint256);

    function claimable(address account) external view returns (uint256 token0Amount, uint256 token1Amount);

    function deposit(IERC20 token, uint256 amount) external;

    function claim() external;

    event Deposited(address indexed token, uint256 amount, uint256 week, uint256 token0Amount, uint256 token1Amount);
    event Claimed(address indexed account, uint256 week, uint256 token0Amount, uint256 token1Amount);
    event SwapPathChanged(address indexed previousValue, address indexed newValue);
    event veTokenChanged(address indexed previousValue, address indexed newValue);
}
