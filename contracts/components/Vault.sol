// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './Pausable.sol';
import './Lockable.sol';
import '../interfaces/IVault.sol';
import '../lib/SafeMath.sol';
import '../lib/SafeERC20.sol';

abstract contract Vault is Pausable, Lockable, IVault {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for ISwapPair;

    ISwapRouter public override swapRouter;
    ISwapPath public override swapPath;
    ISwapPair public override swapPair;
    IFarm public immutable farm;
    uint256 public immutable farmId;
    address public immutable bluebit;

    uint256 public override totalSupply = 0;
    uint256 public override withdrawInterval = 12 hours;
    uint256 public override withdrawFee = 50;

    IERC20[] public rewardTokens;
    mapping(IERC20 => uint256) private _rewardTokens;

    constructor(
        ISwapRouter _swapRouter,
        ISwapPath _swapPath,
        ISwapPair _swapPair,
        IFarm _farm,
        uint256 _farmId,
        address _bluebit
    ) public {
        swapRouter = _swapRouter;
        swapPath = _swapPath;
        swapPair = _swapPair;
        farm = _farm;
        farmId = _farmId;
        bluebit = _bluebit;

        setApprove(uint256(-1));
    }

    modifier onlyBluebit() {
        require(msg.sender == bluebit, 'Vault: caller is not the bluebit');
        _;
    }

    function setApprove(uint256 amount) public onlyOwner {
        swapPair.approve(address(swapRouter), amount);
        IERC20(swapPair.token0()).approve(address(swapRouter), amount);
        IERC20(swapPair.token1()).approve(address(swapRouter), amount);
    }

    function init() external override onlyManager {
        require(totalSupply == 0, 'Vault: already initialized');

        _deposit(swapPair.balanceOf(address(this)));
    }

    function migrate(IVault vault) external override onlyOwner {
        require(address(vault) != address(0), 'Vault: vault address is the zero address');

        _farmWithdraw(totalSupply);

        uint256 depositTokenAmount = swapPair.balanceOf(address(this));
        if (depositTokenAmount > 0) swapPair.safeTransfer(address(vault), depositTokenAmount);

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20 token = rewardTokens[i];
            uint256 amount = token.balanceOf(address(this));
            if (amount > 0) token.safeTransfer(address(vault), amount);
        }

        vault.init();
    }

    function setSwapPath(ISwapPath _address) external onlyOwner {
        require(_address != ISwapPath(0), 'Vault: new address is the zero address');

        emit SwapPathChanged(address(swapPath), address(_address));
        swapPath = _address;
    }

    function addRewardToken(IERC20 rewardToken) external onlyOwner {
        require(rewardToken != IERC20(0), 'Vault: rewardToken address is the zero address');
        require(_rewardTokens[rewardToken] == 0, 'Vault: rewardToken address exist');

        rewardTokens.push(rewardToken);
        _rewardTokens[rewardToken] = rewardTokens.length;
        rewardToken.approve(address(swapRouter), uint256(-1));

        emit RewardTokenAdded(address(rewardToken));
    }

    function removeRewardToken(IERC20 rewardToken) external onlyOwner {
        require(rewardToken != IERC20(0), 'Vault: rewardToken address is the zero address');
        require(_rewardTokens[rewardToken] > 0, 'Vault: rewardToken address not exist');

        uint256 index = _rewardTokens[rewardToken];
        IERC20 last = rewardTokens[rewardTokens.length - 1];

        rewardTokens[index - 1] = last;
        _rewardTokens[last] = index;
        rewardTokens.pop();
        delete _rewardTokens[rewardToken];

        emit RewardTokenRemoved(address(rewardToken));
    }

    function setWithdrawInterval(uint256 _value) external onlyOwner {
        require(_value <= 72 hours, 'Vault: interval cannot be greater than 72 hours');

        emit WithdrawIntervalChanged(withdrawInterval, _value);
        withdrawInterval = _value;
    }

    function setWithdrawFee(uint256 _fee) external onlyOwner {
        require(_fee <= 100, 'Vault: fee cannot be greater than 100');

        emit WithdrawFeeChanged(withdrawFee, _fee);
        withdrawFee = _fee;
    }

    function deposit(uint256 amount) external override notPaused notLocked onlyBluebit {
        if (amount == 0) return;

        swapPair.safeTransferFrom(msg.sender, address(this), amount);
        _deposit(amount);
    }

    function _deposit(uint256 amount) private {
        if (amount == 0) return;

        swapPair.safeIncreaseAllowance(address(farm), amount);
        _farmDeposit(amount);
        totalSupply = totalSupply.add(amount);
    }

    function _farmDeposit(uint256 amount) internal virtual {
        farm.deposit(farmId, amount);
    }

    function withdraw(uint256 amount) external override notPaused notLocked onlyBluebit {
        uint256 balance = swapPair.balanceOf(address(this));
        _farmWithdraw(amount);
        balance = swapPair.balanceOf(address(this)).sub(balance);
        if (balance == 0) return;

        if (balance > totalSupply) balance = totalSupply;
        totalSupply = totalSupply.sub(balance, 'Vault: withdraw amount exceeds deposits');
        swapPair.safeTransfer(msg.sender, balance);
    }

    function _farmWithdraw(uint256 amount) internal virtual {
        farm.withdraw(farmId, amount);
    }

    function harvest(IFeeDistributor feeDistributor) external override notPaused notLocked onlyBluebit {
        _farmHarvest();

        for (uint256 i = 1; i < rewardTokens.length; i++) {
            IERC20 rewardToken = rewardTokens[i];
            uint256 amount = rewardToken.balanceOf(address(this));
            _swap(rewardToken, rewardTokens[0], amount);
        }

        if (rewardTokens.length > 0) _harvest(rewardTokens[0], feeDistributor);
        _deposit(swapPair.balanceOf(address(this)));
    }

    function _farmHarvest() internal virtual {
        farm.withdraw(farmId, 0);
    }

    function _harvest(IERC20 token, IFeeDistributor feeDistributor) private {
        uint256 amount = token.balanceOf(address(this));
        if (amount == 0) return;

        uint256 fee = feeDistributor.totalFee(amount);
        if (fee > 0) {
            token.safeIncreaseAllowance(address(feeDistributor), fee);
            feeDistributor.distribute(token, amount);
            amount = amount.sub(fee);
        }

        IERC20 token0 = IERC20(swapPair.token0());
        IERC20 token1 = IERC20(swapPair.token1());
        uint256 halfAmount = amount.div(2);

        if (token != token0) _swap(token, token0, halfAmount);
        if (token != token1) _swap(token, token1, amount.sub(halfAmount));

        uint256 amount0 = token0.balanceOf(address(this));
        uint256 amount1 = token1.balanceOf(address(this));
        if (amount0 > 0 && amount1 > 0) {
            swapRouter.addLiquidity(swapPair.token0(), swapPair.token1(), amount0, amount1, 0, 0, address(this), block.timestamp.add(600));
        }
    }

    function _swap(
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn
    ) private returns (uint256) {
        if (amountIn == 0) return 0;

        uint256[] memory amounts = swapRouter.swapExactTokensForTokens(
            amountIn,
            0,
            swapPath.get(swapRouter, tokenIn, tokenOut),
            address(this),
            block.timestamp.add(600)
        );
        return amounts[amounts.length.sub(1)];
    }
}
