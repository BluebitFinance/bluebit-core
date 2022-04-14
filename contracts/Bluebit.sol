// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './components/Pausable.sol';
import './components/Lockable.sol';
import './interfaces/IBluebit.sol';
import './lib/SafeMath.sol';
import './lib/SafeERC20.sol';

contract Bluebit is Pausable, Lockable, IBluebit {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for ISwapPair;
    using SafeERC20 for IBluebitToken;

    IveToken public override veToken;
    IBluebitToken public override bluebitToken;
    uint256 public override rewardPerBlock;
    uint256 public override totalAllocPoint;
    IFeeDistributor public override feeDistributor;

    uint256 public factorWeight = 4000;

    mapping(uint256 => mapping(address => User)) public users;
    Pool[] public pools;

    mapping(IVault => uint256) private _pools;

    constructor(
        IveToken _veToken,
        IBluebitToken _bluebitToken,
        uint256 _rewardPerBlock
    ) public {
        veToken = _veToken;
        bluebitToken = _bluebitToken;
        rewardPerBlock = _rewardPerBlock;
    }

    function setveToken(IveToken _address) external onlyOwner {
        require(_address != IveToken(0), 'Bluebit: new address is the zero address');

        emit veTokenChanged(address(veToken), address(_address));
        veToken = _address;
    }

    function setBluebitToken(IBluebitToken _address) external onlyOwner {
        require(_address != IBluebitToken(0), 'Bluebit: new address is the zero address');

        emit BluebitTokenChanged(address(bluebitToken), address(_address));
        bluebitToken = _address;
    }

    function setPool(IVault vault, uint256 allocPoint) external onlyOwner {
        require(vault != IVault(0), 'Bluebit: vault address is the zero address');

        totalAllocPoint = totalAllocPoint.add(allocPoint);
        uint256 index = _pools[vault];
        if (index == 0) {
            pools.push(Pool(vault, 0, 0, allocPoint, 0, block.number, 0, block.number));
            _pools[vault] = pools.length;
        } else {
            totalAllocPoint = totalAllocPoint.sub(pools[index - 1].allocPoint);
            pools[index - 1].allocPoint = allocPoint;
        }

        emit PoolChange(address(vault), _pools[vault], allocPoint);
    }

    function migratePool(uint256 pid, IVault vault) external onlyOwner {
        require(vault != IVault(0), 'Bluebit: vault address is the zero address');

        Pool storage pool = pools[pid];
        _pools[vault] = _pools[pool.vault];
        delete _pools[pool.vault];
        pool.vault = vault;

        emit PoolChange(address(vault), _pools[vault], pool.allocPoint);
    }

    function setFactorWeight(uint256 weight) external onlyManager {
        require(weight <= 10000, 'Bluebit: new weight must be less than 10000');

        emit FactorWeightChanged(factorWeight, weight);
        factorWeight = weight;
    }

    function setRewardPerBlock(uint256 _value) external onlyOwner {
        emit RewardPerBlockChanged(rewardPerBlock, _value);
        rewardPerBlock = _value;
    }

    function setFeeDistributor(IFeeDistributor _address) external onlyOwner {
        require(_address != IFeeDistributor(0), 'Vault: new address is the zero address');

        emit FeeDistributorChanged(address(feeDistributor), address(_address));
        feeDistributor = _address;
    }

    function poolLength() external view override returns (uint256) {
        return pools.length;
    }

    function poolRewards(uint256 pid, uint256 bluebitTokenTotalSupply) public view override returns (uint256 rewards, uint256 fee) {
        Pool memory pool = pools[pid];

        uint256 blocks = _getBlocks(pool.lastRewardBlock, block.number);
        if (blocks == 0) return (0, 0);

        rewards = (totalAllocPoint == 0) ? 0 : blocks.mul(rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        uint256 minableSupply = bluebitToken.maxSupply().sub(bluebitTokenTotalSupply);
        if (rewards > minableSupply) rewards = minableSupply;
        fee = feeDistributor.totalFee(rewards);
        rewards = rewards.sub(fee);
    }

    function pendingRewards(uint256 pid, address account) external view override returns (uint256) {
        Pool memory pool = pools[pid];
        User memory user = users[pid][account];

        uint256 rewardPerWeight = pool.rewardPerWeight;
        if (pool.weights > 0) {
            (uint256 rewards, ) = poolRewards(pid, bluebitToken.totalSupply());
            rewardPerWeight = rewardPerWeight.add(rewards.mul(1e18).div(pool.weights));
        }

        uint256 totalRewards = user.weights.mul(rewardPerWeight).div(1e18);
        if (totalRewards <= user.rewardDebt) return 0;

        return totalRewards.sub(user.rewardDebt);
    }

    function deposit(uint256 pid, uint256 amount) external override notPaused notLocked {
        _mint(_updatePool(pid));
        _harvest(pid, msg.sender);

        if (amount > 0) {
            Pool storage pool = pools[pid];
            User storage user = users[pid][msg.sender];

            pool.vault.swapPair().safeTransferFrom(msg.sender, address(this), amount);
            pool.vault.swapPair().safeIncreaseAllowance(address(pool.vault), amount);

            uint256 totalSupply = pool.vault.totalSupply();
            uint256 shares = (totalSupply == 0) ? amount : amount.mul(pool.shares).div(totalSupply);
            pool.shares = pool.shares.add(shares);
            user.shares = user.shares.add(shares);
            user.lastDepositedTime = block.timestamp;
            user.lastDepositedAmount = user.shares.mul(totalSupply.add(amount)).div(pool.shares);

            pool.vault.deposit(amount);
        }

        _updateWeight(pid, msg.sender);
        emit Deposited(msg.sender, pid, amount);
    }

    function withdraw(uint256 pid, uint256 amount) external override notPaused notLocked {
        _mint(_updatePool(pid));
        _harvest(pid, msg.sender);

        if (amount > 0) {
            Pool storage pool = pools[pid];
            User storage user = users[pid][msg.sender];

            uint256 totalSupply = pool.vault.totalSupply();
            if (totalSupply > 0) {
                uint256 deposits = user.shares.mul(totalSupply).div(pool.shares);
                uint256 shares = 0;
                if (amount >= deposits) {
                    amount = deposits;
                    shares = user.shares;
                } else {
                    shares = amount.mul(pool.shares).div(totalSupply);
                    if (shares > user.shares) shares = user.shares;
                }
                pool.shares = pool.shares.sub(shares);
                user.shares = user.shares.sub(shares);
                user.lastDepositedAmount = (pool.shares == 0) ? 0 : user.shares.mul(totalSupply.sub(amount)).div(pool.shares);

                pool.vault.withdraw(amount);
                amount = pool.vault.swapPair().balanceOf(address(this));
                amount = _withdrawFee(pool, user, amount);
                pool.vault.swapPair().safeTransfer(msg.sender, amount);
            }
        }

        _updateWeight(pid, msg.sender);
        emit Withdrawn(msg.sender, pid, amount);
    }

    function _withdrawFee(
        Pool memory pool,
        User memory user,
        uint256 amount
    ) private returns (uint256) {
        if (block.timestamp.sub(user.lastDepositedTime) < pool.vault.withdrawInterval() && amount > 0) {
            uint256 fee = amount.mul(pool.vault.withdrawFee()).div(10000);
            if (fee == 0) return amount;

            pool.vault.swapPair().safeIncreaseAllowance(address(feeDistributor), fee);
            feeDistributor.distributeWithdrawFee(pool.vault.swapRouter(), pool.vault.swapPair(), fee);
            amount = amount.sub(fee);
        }

        return amount;
    }

    function harvest(uint256 pid) external override notPaused notLocked {
        _mint(_updatePool(pid));
        _harvest(pid, msg.sender);
        _updateWeight(pid, msg.sender);
    }

    function harvests() external override notPaused notLocked {
        uint256 length = pools.length;
        uint256 totalRewards = 0;
        uint256 userRewards = 0;

        uint256 bluebitTokenTotalSupply = bluebitToken.totalSupply();
        for (uint256 i = 0; i < length; i++) {
            uint256 _poolRewards = _updatePool(i, bluebitTokenTotalSupply.add(totalRewards));
            totalRewards = totalRewards.add(_poolRewards);

            User storage user = users[i][msg.sender];
            uint256 rewards = user.weights.mul(pools[i].rewardPerWeight).div(1e18);
            if (rewards > user.rewardDebt) userRewards = userRewards.add(rewards.sub(user.rewardDebt));

            _updateWeight(i, msg.sender);
        }

        _mint(totalRewards);
        bluebitToken.safeTransfer(msg.sender, userRewards);
        emit Harvests(msg.sender, userRewards);
    }

    function compound(uint256 pid) external override notPaused notLocked onlyManager {
        Pool storage pool = pools[pid];

        uint256 oldTotalSupply = pool.vault.totalSupply();
        pool.vault.harvest(feeDistributor);
        uint256 newTotalSupply = pool.vault.totalSupply();

        uint256 blocks = _getBlocks(pool.lastCompoundBlock, block.number);
        if (blocks > 0 && oldTotalSupply > 0 && newTotalSupply > oldTotalSupply)
            pool.interestRatePerBlock = newTotalSupply.sub(oldTotalSupply).mul(1e18).div(oldTotalSupply).div(blocks);

        pool.lastCompoundBlock = block.number;
        emit Compound(pid, pool.shares, newTotalSupply);
    }

    function _mint(uint256 amount) private {
        if (amount == 0) return;

        bluebitToken.mint(address(this), amount);
        uint256 fee = feeDistributor.totalFee(amount);
        if (fee == 0) return;

        bluebitToken.safeIncreaseAllowance(address(feeDistributor), fee);
        feeDistributor.distribute(bluebitToken, amount);
    }

    function _updatePool(uint256 pid, uint256 bluebitTokenTotalSupply) private returns (uint256) {
        Pool storage pool = pools[pid];
        uint256 totalRewards = 0;

        if (pool.weights > 0) {
            (uint256 rewards, uint256 fee) = poolRewards(pid, bluebitTokenTotalSupply);
            totalRewards = rewards.add(fee);
            pool.rewardPerWeight = pool.rewardPerWeight.add(rewards.mul(1e18).div(pool.weights));
        }

        pool.lastRewardBlock = block.number;
        return totalRewards;
    }

    function _updatePool(uint256 pid) private returns (uint256) {
        return _updatePool(pid, bluebitToken.totalSupply());
    }

    function _getBlocks(uint256 from, uint256 to) private pure returns (uint256) {
        return to.sub(from);
    }

    function _harvest(uint256 pid, address account) private {
        Pool storage pool = pools[pid];
        User storage user = users[pid][account];

        uint256 totalRewards = user.weights.mul(pool.rewardPerWeight).div(1e18);
        if (totalRewards <= user.rewardDebt) return;

        uint256 rewards = totalRewards.sub(user.rewardDebt);

        bluebitToken.safeTransfer(account, rewards);
        emit Harvest(account, pid, rewards);
    }

    function _updateWeight(uint256 pid, address account) private {
        Pool storage pool = pools[pid];
        User storage user = users[pid][account];

        uint256 poolDeposits = pool.vault.totalSupply();
        uint256 userDeposits = (pool.shares == 0) ? 0 : user.shares.mul(poolDeposits).div(pool.shares);

        uint256 userFactor = userDeposits.mul(factorWeight).div(10000);
        uint256 poolFactor = poolDeposits.mul(10000 - factorWeight).div(10000).mul(veToken.rate(account)).div(1e18);

        uint256 userWeights = userDeposits.min(userFactor.add(poolFactor));
        pool.weights = pool.weights.add(userWeights).sub(user.weights);
        user.weights = userWeights;

        user.rewardDebt = user.weights.mul(pool.rewardPerWeight).div(1e18);
    }
}
