// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './IERC20.sol';
import './ISwapRouter.sol';

interface ISwapPath {
    function get(
        ISwapRouter swapRouter,
        IERC20 tokenIn,
        IERC20 tokenOut
    ) external view returns (address[] memory path);

    event SwapPathChanged(address indexed swapRouter, address indexed tokenIn, address indexed tokenOut, address[] previousValue, address[] newValue);
}
