// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './IFarm.sol';
import './ISwapPair.sol';
import './ISwapRouter.sol';
import './ISwapPath.sol';
import './IFeeDistributor.sol';

interface IVault {
    function swapRouter() external view returns (ISwapRouter);

    function swapPath() external view returns (ISwapPath);

    function swapPair() external view returns (ISwapPair);

    function withdrawInterval() external view returns (uint256);

    function withdrawFee() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function harvest(IFeeDistributor feeDistributor) external;

    function init() external;

    function migrate(IVault vault) external;

    event WithdrawIntervalChanged(uint256 indexed previousValue, uint256 indexed newValue);
    event WithdrawFeeChanged(uint256 indexed previousValue, uint256 indexed newValue);
    event SwapPathChanged(address indexed previousValue, address indexed newValue);
    event RewardTokenAdded(address indexed token);
    event RewardTokenRemoved(address indexed token);
}
