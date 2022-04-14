// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import '../components/Vault.sol';

contract TrisolarisVault is Vault {
    constructor(
        ISwapRouter _swapRouter,
        ISwapPath _swapPath,
        ISwapPair _swapPair,
        IFarm _farm,
        uint256 _farmId,
        address _bluebit
    ) public Vault(_swapRouter, _swapPath, _swapPair, _farm, _farmId, _bluebit) {}
}
