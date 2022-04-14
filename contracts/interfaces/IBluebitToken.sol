// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './IERC20.sol';

interface IBluebitToken is IERC20 {
    function maxSupply() external view returns (uint256);

    function mint(address account, uint256 amount) external;
}
