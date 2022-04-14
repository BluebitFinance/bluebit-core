// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './ISwapPair.sol';

interface ISwapFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);

    function getPair(address tokenA, address tokenB) external view returns (ISwapPair pair);
}
