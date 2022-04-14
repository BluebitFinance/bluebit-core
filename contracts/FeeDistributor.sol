// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './components/Pausable.sol';
import './components/Lockable.sol';
import './interfaces/IFeeDistributor.sol';
import './interfaces/IRebatePool.sol';
import './interfaces/ISwapRouter.sol';
import './interfaces/ISwapPair.sol';
import './lib/SafeMath.sol';
import './lib/SafeERC20.sol';

contract FeeDistributor is Pausable, Lockable, IFeeDistributor {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for ISwapPair;

    address public override controllerAddress;
    uint256 public override controllerFee = 300;

    address public override treasuryAddress;
    uint256 public override treasuryFee = 100;

    address public override rebateAddress;
    uint256 public override rebateFee = 400;

    address public override adminAddress;
    uint256 public override adminFee = 2000;

    function setControllerFee(uint256 _fee) external onlyOwner {
        require(_fee <= 2000, 'FeeDistributor: fee cannot be greater than 2000');

        emit FeeChanged(controllerFee, _fee, 1);
        controllerFee = _fee;
    }

    function setControllerAddress(address _address) external onlyOwner {
        require(_address != address(0), 'FeeDistributor: new address is the zero address');

        emit AddressChanged(controllerAddress, _address, 1);
        controllerAddress = _address;
    }

    function setTreasuryFee(uint256 _fee) external onlyOwner {
        require(_fee <= 2000, 'FeeDistributor: fee cannot be greater than 2000');

        emit FeeChanged(treasuryFee, _fee, 2);
        treasuryFee = _fee;
    }

    function setTreasuryAddress(address _address) external onlyOwner {
        require(_address != address(0), 'FeeDistributor: new address is the zero address');

        emit AddressChanged(treasuryAddress, _address, 2);
        treasuryAddress = _address;
    }

    function setRebateFee(uint256 _fee) external onlyOwner {
        require(_fee <= 2000, 'FeeDistributor: fee cannot be greater than 2000');

        emit FeeChanged(rebateFee, _fee, 3);
        rebateFee = _fee;
    }

    function setRebateAddress(address _address) external onlyOwner {
        require(_address != address(0), 'FeeDistributor: new address is the zero address');

        emit AddressChanged(rebateAddress, _address, 3);
        rebateAddress = _address;
    }

    function setAdminFee(uint256 _fee) external onlyOwner {
        require(_fee <= 10000, 'FeeDistributor: fee cannot be greater than 10000');

        emit FeeChanged(adminFee, _fee, 4);
        adminFee = _fee;
    }

    function setAdminAddress(address _address) external onlyOwner {
        require(_address != address(0), 'FeeDistributor: new address is the zero address');

        emit AddressChanged(adminAddress, _address, 4);
        adminAddress = _address;
    }

    function totalFee(uint256 amount) public view override returns (uint256) {
        return amount.mul(controllerFee.add(treasuryFee).add(rebateFee)).div(10000);
    }

    function distribute(IERC20 token, uint256 amount) external override notPaused notLocked {
        token.safeTransferFrom(msg.sender, address(this), totalFee(amount));

        if (controllerFee > 0) {
            uint256 fee = amount.mul(controllerFee).div(10000);
            uint256 _adminFee = fee.mul(adminFee).div(10000);
            token.safeTransfer(adminAddress, _adminFee);
            token.safeTransfer(controllerAddress, fee.sub(_adminFee));
        }

        if (treasuryFee > 0) {
            uint256 fee = amount.mul(treasuryFee).div(10000);
            token.safeTransfer(treasuryAddress, fee);
        }

        if (rebateFee > 0) {
            uint256 fee = amount.mul(rebateFee).div(10000);
            if (fee > 0) {
                token.safeIncreaseAllowance(rebateAddress, fee);
                IRebatePool(rebateAddress).deposit(token, fee);
            }
        }
    }

    function distributeWithdrawFee(
        ISwapRouter,
        ISwapPair swapPair,
        uint256 amount
    ) external override notPaused notLocked {
        swapPair.safeTransferFrom(msg.sender, address(this), amount);

        uint256 _adminFee = amount.mul(adminFee).div(10000);
        uint256 _controllerFee = amount.sub(_adminFee);
        if (_adminFee > 0) swapPair.safeTransfer(adminAddress, _adminFee);
        if (_controllerFee > 0) swapPair.safeTransfer(controllerAddress, _controllerFee);
    }
}
