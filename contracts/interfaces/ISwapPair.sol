// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './IERC20.sol';
import './ISwapFactory.sol';

interface ISwapPair is IERC20 {
    function factory() external view returns (ISwapFactory);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}
