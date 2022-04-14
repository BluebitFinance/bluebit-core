// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './components/Pausable.sol';
import './components/Lockable.sol';
import './interfaces/IRebatePool.sol';
import './interfaces/ISwapRouter.sol';
import './interfaces/ISwapPath.sol';
import './interfaces/IveToken.sol';
import './lib/SafeMath.sol';
import './lib/SafeERC20.sol';

contract RebatePool is Pausable, Lockable, IRebatePool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant duration = 7 days;

    ISwapRouter public swapRouter;
    ISwapPath public swapPath;
    IveToken public veToken;
    IERC20 public override token0;
    IERC20 public override token1;
    uint256 public startPeriod;

    mapping(uint256 => mapping(address => uint256)) public deposits;
    mapping(uint256 => mapping(address => uint256)) public daily;
    mapping(address => uint256) public claimed;

    constructor(
        ISwapRouter _swapRouter,
        ISwapPath _swapPath,
        IveToken _veToken,
        IERC20 _token0,
        IERC20 _token1
    ) public {
        swapRouter = _swapRouter;
        swapPath = _swapPath;
        veToken = _veToken;
        token0 = _token0;
        token1 = _token1;
        startPeriod = _getPeriod(block.timestamp);
    }

    function setSwapPath(ISwapPath _address) external onlyOwner {
        require(_address != ISwapPath(0), 'RebatePool: new address is the zero address');

        emit SwapPathChanged(address(swapPath), address(_address));
        swapPath = _address;
    }

    function setveToken(IveToken _address) external onlyOwner {
        require(_address != IveToken(0), 'RebatePool: new address is the zero address');

        emit veTokenChanged(address(veToken), address(_address));
        veToken = _address;
    }

    function _getPeriod(uint256 timestamp) private pure returns (uint256) {
        return timestamp.div(duration).mul(duration);
    }

    function deposit(IERC20 token, uint256 amount) external override notPaused notLocked {
        if (amount == 0) return;

        token.safeTransferFrom(msg.sender, address(this), amount);
        token.safeIncreaseAllowance(address(swapRouter), amount);
        uint256 halfAmount = amount.div(2);

        uint256 token0Amount = (token == token0) ? halfAmount : _swap(token, token0, halfAmount);
        uint256 token1Amount = (token == token1) ? amount.sub(halfAmount) : _swap(token, token1, amount.sub(halfAmount));

        uint256 period = _getPeriod(block.timestamp);

        deposits[period][address(token0)] = deposits[period][address(token0)].add(token0Amount);
        deposits[period][address(token1)] = deposits[period][address(token1)].add(token1Amount);

        uint256 today = block.timestamp.div(1 days).mul(1 days);
        daily[today][address(token0)] = daily[today][address(token0)].add(token0Amount);
        daily[today][address(token1)] = daily[today][address(token1)].add(token1Amount);

        emit Deposited(address(token), amount, period, token0Amount, token1Amount);
    }

    function lastdays(uint256 _days) external view override returns (uint256 token0Amount, uint256 token1Amount) {
        uint256 _duration = 1 days;
        uint256 today = block.timestamp.div(_duration).mul(_duration);
        for (uint256 i = 0; i < _days; i++) {
            uint256 day = today.sub(_duration.mul(i + 1));
            token0Amount = token0Amount.add(daily[day][address(token0)]);
            token1Amount = token1Amount.add(daily[day][address(token1)]);
        }
    }

    function depositsAt(uint256 timestamp) public view override returns (uint256 token0Amount, uint256 token1Amount) {
        uint256 period = _getPeriod(timestamp);
        token0Amount = deposits[period][address(token0)];
        token1Amount = deposits[period][address(token1)];
    }

    function claimable(address account) external view override returns (uint256 token0Amount, uint256 token1Amount) {
        (token0Amount, token1Amount) = _claimable(account, _getPeriod(block.timestamp).sub(duration));
    }

    function veRateAt(address account, uint256 timestamp) external view override returns (uint256) {
        uint256 period = _getPeriod(timestamp);
        if (period < startPeriod) period = startPeriod;
        return veToken.rateAt(account, period);
    }

    function _claimable(address account, uint256 claimePeriod) private view returns (uint256 token0Amount, uint256 token1Amount) {
        uint256 claimedPeriod = (claimed[account] == 0) ? startPeriod : claimed[account].add(duration);
        for (uint256 period = claimedPeriod; period <= claimePeriod; period = period.add(duration)) {
            uint256 veTokenPeriod = (period <= startPeriod) ? period : period.sub(duration);
            uint256 veRate = veToken.rateAt(account, veTokenPeriod);
            if (veRate == 0) continue;

            token0Amount = token0Amount.add(deposits[period][address(token0)].mul(veRate).div(1e18));
            token1Amount = token1Amount.add(deposits[period][address(token1)].mul(veRate).div(1e18));
        }
    }

    function claim() external override notPaused notLocked {
        uint256 period = _getPeriod(block.timestamp).sub(duration);
        (uint256 token0Amount, uint256 token1Amount) = _claimable(msg.sender, period);
        claimed[msg.sender] = period;

        if (token0Amount > 0) token0.safeTransfer(msg.sender, token0Amount);
        if (token1Amount > 0) token1.safeTransfer(msg.sender, token1Amount);

        emit Claimed(msg.sender, period, token0Amount, token1Amount);
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
