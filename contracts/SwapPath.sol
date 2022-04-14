// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './components/Ownable.sol';
import './interfaces/ISwapPath.sol';
import './interfaces/ISwapRouter.sol';

contract SwapPath is Ownable, ISwapPath {
    mapping(ISwapRouter => mapping(IERC20 => mapping(IERC20 => address[]))) private _paths;

    function set(
        ISwapRouter swapRouter,
        IERC20 tokenIn,
        IERC20 tokenOut,
        address[] memory path
    ) external onlyOwner {
        require(tokenIn != IERC20(0), 'SwapPath: tokenIn address is the zero address');
        require(tokenOut != IERC20(0), 'SwapPath: tokenOut address is the zero address');
        require(path[0] == address(tokenIn), 'SwapPath: invalid path');
        require(path[path.length - 1] == address(tokenOut), 'SwapPath: invalid path');

        emit SwapPathChanged(address(swapRouter), address(tokenIn), address(tokenOut), _paths[swapRouter][tokenIn][tokenOut], path);
        _paths[swapRouter][tokenIn][tokenOut] = path;
    }

    function get(
        ISwapRouter swapRouter,
        IERC20 tokenIn,
        IERC20 tokenOut
    ) external view override returns (address[] memory path) {
        return _paths[swapRouter][tokenIn][tokenOut];
    }
}
