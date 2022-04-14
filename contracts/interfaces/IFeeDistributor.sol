// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './ISwapRouter.sol';
import './ISwapPair.sol';

interface IFeeDistributor {
    function controllerAddress() external view returns (address);

    function controllerFee() external view returns (uint256);

    function treasuryAddress() external view returns (address);

    function treasuryFee() external view returns (uint256);

    function rebateAddress() external view returns (address);

    function rebateFee() external view returns (uint256);

    function adminAddress() external view returns (address);

    function adminFee() external view returns (uint256);

    function totalFee(uint256 amount) external view returns (uint256);

    function distribute(IERC20 token, uint256 amount) external;

    function distributeWithdrawFee(
        ISwapRouter swapRouter,
        ISwapPair swapPair,
        uint256 amount
    ) external;

    event FeeChanged(uint256 indexed previousValue, uint256 indexed newValue, uint256 indexed valueType);
    event AddressChanged(address indexed previousValue, address indexed newValue, uint256 indexed valueType);
}
