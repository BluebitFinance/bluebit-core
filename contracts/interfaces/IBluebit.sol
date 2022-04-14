// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './IERC20.sol';
import './IVault.sol';
import './IveToken.sol';
import './IBluebitToken.sol';

interface IBluebit {
    struct User {
        uint256 shares;
        uint256 weights;
        uint256 rewardDebt;
        uint256 lastDepositedTime;
        uint256 lastDepositedAmount;
    }

    struct Pool {
        IVault vault;
        uint256 shares;
        uint256 weights;
        uint256 allocPoint;
        uint256 rewardPerWeight;
        uint256 lastRewardBlock;
        uint256 interestRatePerBlock;
        uint256 lastCompoundBlock;
    }

    function veToken() external view returns (IveToken);

    function bluebitToken() external view returns (IBluebitToken);

    function rewardPerBlock() external view returns (uint256);

    function totalAllocPoint() external view returns (uint256);

    function feeDistributor() external view returns (IFeeDistributor);

    function poolLength() external view returns (uint256);

    function poolRewards(uint256 pid, uint256 bluebitTokenTotalSupply) external view returns (uint256 rewards, uint256 fee);

    function pendingRewards(uint256 pid, address account) external view returns (uint256);

    function deposit(uint256 pid, uint256 amount) external;

    function withdraw(uint256 pid, uint256 amount) external;

    function harvest(uint256 pid) external;

    function harvests() external;

    function compound(uint256 pid) external;

    event Deposited(address indexed account, uint256 pid, uint256 amount);
    event Withdrawn(address indexed account, uint256 pid, uint256 amount);
    event Harvest(address indexed account, uint256 pid, uint256 amount);
    event Harvests(address indexed account, uint256 amount);
    event Compound(uint256 pid, uint256 totalShares, uint256 totalSupply);

    event PoolChange(address indexed vault, uint256 pid, uint256 allocPoint);
    event FactorWeightChanged(uint256 indexed previousValue, uint256 indexed newValue);
    event RewardPerBlockChanged(uint256 indexed previousValue, uint256 indexed newValue);
    event FeeDistributorChanged(address indexed previousValue, address indexed newValue);
    event veTokenChanged(address indexed previousValue, address indexed newValue);
    event BluebitTokenChanged(address indexed previousValue, address indexed newValue);
}
