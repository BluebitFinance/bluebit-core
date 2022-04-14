// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './components/Token.sol';
import './interfaces/IBluebitToken.sol';

contract BluebitToken is IBluebitToken, Token {
    uint256 public constant override maxSupply = 100_000_000 ether;

    constructor() public Token('BlueBit Token', 'BBT', 18, 0) {}

    function mint(address account, uint256 amount) external override onlyManager {
        require(totalSupply.add(amount) <= maxSupply, 'BluebitToken: Max supply exceeded');

        _mint(account, amount);
    }
}
