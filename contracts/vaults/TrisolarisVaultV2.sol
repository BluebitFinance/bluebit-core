// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import '../components/Vault.sol';

interface ITrisolarisVaultV2 {
    function deposit(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function withdrawAndHarvest(
        uint256 pid,
        uint256 amount,
        address to
    ) external;
}

contract TrisolarisVaultV2 is Vault {
    constructor(
        ISwapRouter _swapRouter,
        ISwapPath _swapPath,
        ISwapPair _swapPair,
        IFarm _farm,
        uint256 _farmId,
        address _bluebit
    ) public Vault(_swapRouter, _swapPath, _swapPair, _farm, _farmId, _bluebit) {}

    function _farmDeposit(uint256 amount) internal override {
        ITrisolarisVaultV2(address(farm)).deposit(farmId, amount, address(this));
    }

    function _farmWithdraw(uint256 amount) internal override {
        ITrisolarisVaultV2(address(farm)).withdrawAndHarvest(farmId, amount, address(this));
    }

    function _farmHarvest() internal override {
        ITrisolarisVaultV2(address(farm)).withdrawAndHarvest(farmId, 0, address(this));
    }
}
